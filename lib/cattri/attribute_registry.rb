# frozen_string_literal: true

require_relative "attribute"
require_relative "error"

module Cattri
  # Cattri::AttributeDefinitions is the centralized registry and dispatcher for attribute declarations.
  #
  # It receives attribute definition calls (e.g., from `.cattr` or `.iattr`) and:
  # - Validates attribute name and options
  # - Instantiates a Cattri::Attribute
  # - Registers it for tracking and introspection
  # - Applies or defers method generation depending on context
  #
  # This class isolates declaration logic from method definition logic (handled by Cattri::AttributeCompiler),
  # and supports both eager and deferred registration.
  class AttributeRegistry
    # @return [Cattri::Context] the context in which attributes will be defined or deferred
    attr_reader :context

    # @param context [Cattri::Context] the context used to apply or defer attribute definitions
    def initialize(context)
      @context = context
    end

    # Returns attribute definitions for the given level, with optional ancestor traversal.
    #
    # By default, this method returns only the attributes defined directly on the current
    # context's target (class or module). If `with_ancestors: true` is passed, it walks the
    # full inheritance and inclusion chain to gather all visible attributes of the specified level.
    #
    # @example
    #   attribute_registry.defined_attributes(:class)
    #   # => { :enabled => #<Cattri::Attribute ...> }
    #
    # @example With inheritance
    #   attribute_registry.defined_attributes(:class, with_ancestors: true)
    #   # => { :enabled => ..., :config => ... } # includes inherited and mixed-in attrs
    #
    # @param level [Symbol] the attribute level (:class or :instance)
    # @param with_ancestors [Boolean] whether to include attributes from ancestors and included modules
    # @return [Hash{Symbol => Cattri::Attribute}] a frozen hash of attributes for the given level
    #
    # @raise [Cattri::AttributeError] if `level` is not supported (should be pre-validated by caller)
    def defined_attributes(level, with_ancestors: false)
      return __defined_attributes[level].freeze unless with_ancestors

      context.attribute_sources
             .select { |mod| mod.respond_to?(:attribute_registry, true) }
             .flat_map { |mod| mod.send(:attribute_registry).defined_attributes(level).to_a }
             .to_h
             .merge(__defined_attributes[level])
             .freeze
    end

    # Returns the attribute definition for the given level and name, or nil if not found.
    #
    # This method is non-strict and will return `nil` if the attribute is not defined.
    #
    # @param level [Symbol] either `:class` or `:instance`
    # @param name [Symbol, String]
    # @return [Cattri::Attribute, nil]
    def fetch_attribute(level, name)
      __defined_attributes.dig(level.to_sym, name.to_sym)
    end

    # Returns the attribute definition for the given level and name, or raises if not found.
    #
    # This method is strict and will raise an error if the requested attribute is not defined.
    #
    # @param level [Symbol] either `:class` or `:instance`
    # @param name [Symbol, String]
    # @raise [Cattri::AttributeNotDefinedError] if the attribute does not exist
    # @return [Cattri::Attribute]
    def fetch_attribute!(level, name)
      __defined_attributes.dig(level.to_sym, name.to_sym) or
        raise Cattri::AttributeNotDefinedError, "#{level.capitalize} attribute :#{name} has not been defined"
    end

    # Defines one or more class-level attributes.
    #
    # Delegates to the internal attribute dispatcher.
    #
    # @param names [Array<Symbol>] attribute names
    # @param options [Hash] attribute options
    # @param block [Proc, nil] optional coercion block
    # @return [void]
    def define_class_attributes(names, options: {}, block: nil)
      define_attributes(names, :class, options.merge(defined_in: context), block)
    end

    # Defines one or more instance-level attributes.
    #
    # Delegates to the internal attribute dispatcher.
    #
    # @param names [Array<Symbol>] attribute names
    # @param options [Hash] attribute options
    # @param block [Proc, nil] optional coercion block
    # @return [void]
    def define_instance_attributes(names, options: {}, block: nil)
      define_attributes(names, :instance, options, block)
    end

    # Reapplies method definitions for an existing attribute.
    #
    # This clears previously defined methods (tracked via context) and re-applies
    # the full definition using `apply_definition!`. If the attribute's context
    # defers definition (e.g., it's a module), the redefinition is deferred instead.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def redefine_attribute!(attribute)
      return defer_definition(attribute) if context.defer_definitions?
      raise Cattri::FinalAttributeError.new(attribute: attribute) if attribute.final?

      context.clear_defined_methods_for!(attribute)
      apply_definition!(attribute)
    end

    # Updates the setter logic of an existing attribute and reapplies its method definitions.
    #
    # This replaces the attribute’s current setter with the given block, normalizes the setter,
    # and triggers a full redefinition via `redefine_attribute!`. This may include clearing
    # and re-applying readers, writers, and predicates depending on attribute configuration.
    #
    # @param attribute [Cattri::Attribute]
    # @param block [Proc]
    # @raise [Cattri::AttributeNotDefinedError] if the attribute is nil
    # @raise [Cattri::MissingBlockError] if the block is missing
    # @return [void]
    def redefine_attribute_setter!(attribute, block)
      raise Cattri::EmptyAttributeError unless attribute
      raise Cattri::MissingBlockError.new(attribute: attribute) unless block
      raise Cattri::FinalAttributeError.new(attribute: attribute) if attribute.final?

      attribute.instance_variable_set(:@setter, attribute.send(:normalize_setter, block))
      redefine_attribute!(attribute)
    end

    private

    # Lazily initializes the internal attribute registry.
    #
    # @return [Hash{Symbol => Hash{Symbol => Cattri::Attribute}}]
    def __defined_attributes
      @__defined_attributes ||= Hash.new { |h, k| h[k] = {} }
    end

    # Applies a set of previously copied attributes into a new context.
    #
    # This is used during inheritance to ensure that attributes copied from a
    # superclass are properly re-registered and their methods redefined in the
    # subclass. It temporarily overrides the internal context reference to ensure
    # the copied definitions are scoped correctly.
    #
    # @param attributes [Array<Cattri::Attribute>] the copied attributes to apply
    # @param target_context [Cattri::Context] the target context for the definitions
    # @return [void]
    def apply_copied_attributes(*attributes, target_context:)
      current_context = context
      @context = target_context

      begin
        attributes.each do |attribute|
          process_attribute(attribute)
        end
      ensure
        @context = current_context
      end
    end

    # Validates and dispatches a set of attribute declarations.
    #
    # Handles:
    # - Unsupported types
    # - Ambiguous block usage
    # - Predicate name restrictions
    #
    # @param names [Array<Symbol>] attribute names
    # @param level [Symbol] :class or :instance
    # @param options [Hash] attribute options
    # @param block [Proc, nil] optional coercion block
    # @return [void]
    def define_attributes(names, level, options, block)
      raise Cattri::UnsupportedAttributeLevelError, level unless Cattri::Attribute::ATTRIBUTE_LEVELS.include?(level)
      raise Cattri::AmbiguousBlockError if names.size > 1 && block

      names.each do |name|
        if name.end_with?("?")
          raise Cattri::AttributeError,
                "Attribute names ending in '?' are not allowed. Use `predicate: true` or `cattr_alias` instead."
        end

        define_attribute(name, level, options, block)
      end
    end

    # Validates, registers, and applies or defers an individual attribute definition.
    #
    # @param name [Symbol] the attribute name
    # @param level [Symbol] the attribute level (:class or :instance)
    # @param options [Hash] attribute options
    # @param block [Proc, nil] optional coercion block
    # @return [void]
    def define_attribute(name, level, options, block)
      attribute = Cattri::Attribute.new(name, level, **options, &block)
      process_attribute(attribute)
    end

    # Processes a new or copied attribute definition.
    #
    # This method is responsible for adding an attribute to the internal registry
    # (`__defined_attributes`) and determining whether it should be applied immediately
    # or deferred. Deferred attributes are queued for later definition when a module
    # is included or extended.
    #
    # It is used both for freshly declared attributes and during inheritance-based
    # copying via `.dup`.
    #
    # @param attribute [Cattri::Attribute] the attribute to register
    # @raise [Cattri::AttributeDefinedError] if the attribute is already defined for the given level and name
    # @return [void]
    def process_attribute(attribute)
      level, name = attribute.to_h.values_at(:level, :name)
      raise Cattri::AttributeDefinedError.new(attribute: attribute) if __defined_attributes[level].key?(name)

      __defined_attributes[level][name] = attribute
      return defer_definition(attribute) if context.defer_definitions?

      apply_definition!(attribute)
    end

    # Registers an attribute for deferred definition.
    #
    # Ensures the target is extended with `Cattri::DeferredAttributes`
    # and passes the attribute to be stored for later application.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def defer_definition(attribute)
      context.ensure_deferred_support!
      context.target.defer_attribute(attribute)
    end

    # Applies an attribute definition immediately via Cattri::AttributeCompiler.
    #
    # This defines the appropriate readers, writers, and predicates.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    # @raise [Cattri::AttributeDefinitionError] if method definition fails
    def apply_definition!(attribute)
      Cattri::AttributeCompiler.send(:"#{attribute.level}_accessor", attribute, context)
    rescue StandardError => e
      raise Cattri::AttributeDefinitionError.new(attribute: attribute, error: e)
    end
  end
end
