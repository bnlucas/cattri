# frozen_string_literal: true

require "set"
require_relative "deferred_attributes"

module Cattri
  # Cattri::Context encapsulates the class or module that attributes are being defined on.
  #
  # It provides a safe interface for dynamically defining methods and tracking metadata,
  # such as declared accessors, access visibility, and deferred attribute declarations.
  #
  # It handles:
  # - Attribute method definitions (reader/writer/predicate)
  # - Visibility enforcement
  # - Target resolution (instance vs. class-level)
  # - Method deduplication and tracking
  #
  # All method definitions occur directly on the resolved target (e.g., the class or its singleton).
  class Context
    # The class or module that owns the attributes.
    #
    # @return [Module]
    attr_reader :target

    # Initializes the context wrapper.
    #
    # @param target [Module, Class] the receiver where attributes are defined
    def initialize(target)
      @target = target
    end

    # Returns a frozen copy of all attribute methods explicitly defined by this context.
    #
    # This does not include inherited or module-defined methods.
    #
    # @return [Hash{Symbol => Set<Symbol>}] map of attribute name to defined method names
    def defined_methods
      (@__cattri_defined_methods ||= {}).dup.freeze # steep:ignore
    end

    # Whether this target should defer method definitions (e.g., if it's a module).
    #
    # @return [Boolean]
    def defer_definitions?
      @target.is_a?(Module) && !@target.is_a?(Class)
    end

    # Ensures the target includes Cattri::DeferredAttributes if needed.
    #
    # Used to prepare modules for later application of attributes when included elsewhere.
    #
    # @return [void]
    def ensure_deferred_support!
      return if @target < Cattri::DeferredAttributes

      @target.extend(Cattri::DeferredAttributes)
    end

    # All ancestors and included modules used for attribute lookup and inheritance.
    #
    # @return [Array<Module>]
    def attribute_lookup_sources
      ([@target] + @target.ancestors + @target.singleton_class.included_modules).uniq
    end

    # Defines a method for the given attribute unless already defined locally.
    #
    # Respects attribute-level force overwrite and enforces visibility rules.
    #
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol, nil] optional method name override
    # @yield method implementation block
    # @raise [Cattri::AttributeError] if method is already defined and not forced
    # @return [void]
    def define_method(attribute, name: nil, &block)
      name = (name || attribute.name).to_sym
      target = target_for(attribute)

      if method_defined?(attribute, name: name)
        raise Cattri::AttributeError, "Method `:#{name}` already defined on #{target}"
      end

      define_method!(target, attribute, name, &block)
    end

    # Checks if the given method is already defined on the resolved target.
    #
    # Only checks methods directly defined on the class or singleton—not ancestors.
    #
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol, nil]
    # @return [Boolean]
    def method_defined?(attribute, name: nil)
      normalized_name = (name || attribute.name).to_sym
      target = target_for(attribute)

      defined_locally = (
        target.public_instance_methods(false) +
          target.protected_instance_methods(false) +
          target.private_instance_methods(false)
      )

      defined_locally.include?(normalized_name) ||
        __cattri_defined_methods[attribute.name].include?(normalized_name)
    end

    # Resolves and returns the module or class where methods and storage should be defined
    # for the given attribute. Ensures the internal store is included on the resolved target.
    #
    # - For class-level attributes, this returns the singleton class unless it's already a singleton.
    # - For instance-level attributes, this returns the class/module directly.
    #
    # @param attribute [Cattri::Attribute]
    # @return [Module]
    def target_for(attribute)
      return @target if attribute.class_attribute? && singleton_class?(@target)

      attribute.class_attribute? ? @target.singleton_class : @target
    end

    # Determines the object (class/module or runtime instance) that should hold
    # the backing storage for the given attribute.
    #
    # - For class-level attributes, uses the singleton class of `defined_in` or the module itself
    # - For instance-level attributes, uses the provided instance
    #
    # @param attribute [Cattri::Attribute]
    # @param instance [Object, nil] the runtime instance, if needed for instance-level access
    # @return [Object] the receiver for attribute value storage
    # @raise [Cattri::Error] if instance is required but missing
    def storage_receiver_for(attribute, instance = nil)
      receiver =
        if attribute.class_attribute?
          resolve_class_storage_for(attribute, instance)
        elsif instance
          instance
        else
          raise Cattri::Error, "Missing runtime instance for instance-level attribute :#{attribute.name}"
        end

      install_internal_store!(receiver)
      receiver
    end

    private

    # Internal tracking of explicitly defined methods per attribute.
    #
    # @return [Hash{Symbol => Set<Symbol>}]
    def __cattri_defined_methods
      @__cattri_defined_methods ||= Hash.new { |h, k| h[k] = Set.new }
    end

    # Determines whether the object is a singleton_class or not.
    #
    # @param obj [Object]
    # @return [Boolean]
    def singleton_class?(obj)
      obj.singleton_class? # Ruby 3.2+
    rescue NoMethodError
      obj.inspect.start_with?("#<Class:")
    end

    # Resolves the proper class-level storage receiver for the attribute.
    #
    # @param attribute [Cattri::Attribute]
    # @param instance [Object, nil]
    # @return [Object]
    def resolve_class_storage_for(attribute, instance)
      if attribute.final?
        singleton_class?(attribute.defined_in) ? attribute.defined_in : attribute.defined_in.singleton_class
      else
        attribute_scope = instance || attribute.defined_in
        attribute_scope.singleton_class
      end
    end

    # Installs the internal store on the receiver if not present.
    #
    # @param receiver [Object]
    # @return [void]
    def install_internal_store!(receiver)
      return if receiver.respond_to?(:cattri_variables)

      if singleton_class?(receiver)
        receiver.extend(Cattri::InternalStore)
      else
        receiver.include(Cattri::InternalStore) # steep:ignore
      end
    end

    # Defines the method and applies its access visibility.
    #
    # @param target [Module]
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol]
    # @yield method implementation
    # @return [void]
    def define_method!(target, attribute, name, &block)
      target.class_eval { define_method(name, &block) } # steep:ignore
      __cattri_defined_methods[attribute.name] << name

      apply_visibility!(target, name, attribute)
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to define accessor methods for `:#{name}` on #{target}. Error: #{e.message}"
    end

    # Applies visibility (`public`, `protected`, `private`) to a method.
    #
    # Skips application for `:public` (default in Ruby).
    #
    # @param target [Module]
    # @param name [Symbol]
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def apply_visibility!(target, name, attribute)
      visibility = effective_visibility(attribute, name)
      return if visibility == :public

      Module.instance_method(visibility).bind(target).call(name)
    end

    # Determines the effective visibility of the attribute.
    #
    # - If the attribute has no public writer or reader (i.e., `expose: :write` or `:none`)
    #   - Returns `:protected` for class-level attributes
    #   - Returns `:private` for instance-level attributes
    # - Otherwise, returns the explicitly declared visibility (`attribute.visibility`)
    #
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol]
    # @return [Symbol] one of `:public`, `:protected`, or `:private`
    def effective_visibility(attribute, name)
      return :protected if attribute.class_attribute? && internal_method?(attribute, name)
      return :private if !attribute.class_attribute? && internal_method?(attribute, name)

      Cattri::AttributeOptions.validate_visibility!(attribute.visibility)
    end

    # Determines whether the given method name (accessor or writer)
    # should be treated as internal-only based on the attribute's `expose` configuration.
    #
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol, String]
    # @return [Boolean]
    def internal_method?(attribute, name)
      return attribute.internal_writer? if name.to_s.end_with?("=")

      attribute.internal_reader?
    end
  end
end
