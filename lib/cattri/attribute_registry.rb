# frozen_string_literal: true

require_relative "attribute_compiler"

module Cattri
  # Cattri::AttributeRegistry is responsible for managing attribute definitions
  # for a given context (class or module). It validates uniqueness, applies
  # definition logic, and supports inheritance and introspection.
  #
  # It handles both eager and deferred attribute compilation and ensures correct
  # behavior for `scope: :class`, `final: true`, and other attribute options.
  class AttributeRegistry
    # @return [Cattri::Context] the context this registry operates within
    attr_reader :context

    # Initializes a new registry for the provided context.
    #
    # @param context [Cattri::Context]
    def initialize(context)
      @context = context
    end

    # Returns the attributes registered directly on this context.
    #
    # @return [Hash{Symbol => Cattri::Attribute}]
    def registered_attributes
      (@__cattri_registered_attributes ||= {}).dup.freeze # steep:ignore
    end

    # Returns all known attributes, optionally including inherited definitions.
    #
    # @param with_ancestors [Boolean] whether to include ancestors
    # @return [Hash{Symbol => Cattri::Attribute}]
    def defined_attributes(with_ancestors: false)
      return registered_attributes unless with_ancestors

      context.attribute_lookup_sources
             .select { |mod| mod.respond_to?(:attribute_registry, true) }
             .flat_map { |mod| mod.send(:attribute_registry).registered_attributes.to_a }
             .to_h
             .merge(registered_attributes)
             .freeze
    end

    # Fetches an attribute by name, or returns nil.
    #
    # @param name [String, Symbol]
    # @param with_ancestors [Boolean]
    # @return [Cattri::Attribute, nil]
    def fetch_attribute(name, with_ancestors: false)
      defined_attributes(with_ancestors: with_ancestors)[name.to_sym]
    end

    # Fetches an attribute by name, or raises if not found.
    #
    # @param name [String, Symbol]
    # @param with_ancestors [Boolean]
    # @return [Cattri::Attribute]
    # @raise [Cattri::AttributeError] if the attribute is not defined
    def fetch_attribute!(name, with_ancestors: false)
      defined_attributes(with_ancestors: with_ancestors).fetch(name.to_sym) do
        raise Cattri::AttributeError, "Attribute :#{name} has not been defined"
      end
    end

    # Defines a new attribute and registers it on the current context.
    #
    # @param name [String, Symbol] the attribute name
    # @param value [Object, Proc, nil] default value or initializer
    # @param options [Hash] attribute options (`:class`, `:final`, etc.)
    # @yield [*args] optional transformation block used as setter
    # @return [Array<Symbol>] list of methods defined by this attribute
    # @raise [Cattri::AttributeError] if the name is already defined
    def define_attribute(name, value, **options, &block)
      name = name.to_sym
      validate_unique!(name)

      options_with_default = options.merge(default: value)
      attribute = Cattri::Attribute.new(
        name,
        defined_in: context.target,
        **options_with_default,
        &block
      )

      register_attribute(attribute)
      attribute.allowed_methods
    end

    private

    # Validates that no attribute with the same name is already registered.
    #
    # @param name [Symbol]
    # @raise [Cattri::AttributeError]
    def validate_unique!(name)
      return unless instance_variable_defined?(:@__cattri_registered_attributes)
      return unless @__cattri_registered_attributes.key?(name)

      raise Cattri::AttributeError, "Attribute :#{name} has already been defined"
    end

    # Registers an attribute and applies or defers its definition.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def register_attribute(attribute)
      unless instance_variable_defined?(:@__cattri_registered_attributes)
        (@__cattri_registered_attributes ||= {}) # steep:ignore
      end

      @__cattri_registered_attributes[attribute.name] = attribute
      return defer_definition(attribute) if context.defer_definitions?

      apply_definition!(attribute)
    end

    # Defers the attribute definition if in a module context.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def defer_definition(attribute)
      context.ensure_deferred_support!
      context.target.defer_attribute(attribute) # steep:ignore
    end

    # Applies the attribute definition using the compiler.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    # @raise [Cattri::AttributeError]
    def apply_definition!(attribute)
      Cattri::AttributeCompiler.define_accessor(attribute, context)
    rescue StandardError => e
      raise Cattri::AttributeError, "Attribute #{attribute.name} could not be defined. Error: #{e.message}"
    end
  end
end
