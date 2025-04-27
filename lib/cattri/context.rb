# frozen_string_literal: true

require "set"

module Cattri
  # Provides a controlled interface for defining methods and instance variables
  # on a target class or module. Used internally by Cattri to define attribute
  # readers and writers while preserving access visibility and tracking which
  # methods were explicitly created.
  #
  # This abstraction allows class and instance attribute logic to be composed
  # consistently and safely across both standard and singleton contexts.
  #
  # It ensures that attribute methods are only defined directly on the current
  # class or singleton, avoiding conflicts with inherited behavior.
  class Context
    # Allowed Ruby visibility levels for methods.
    ACCESS_LEVELS = %i[public protected private].freeze
    private_constant :ACCESS_LEVELS

    # @return [Module, Class] the receiver to which accessors will be added
    attr_reader :target

    # Initializes a new context wrapper around the given target.
    #
    # If the target is a singleton class, it is normalized to its attached object
    # (e.g., a class or module). This avoids duplicate method definitions.
    #
    # @param target [Module, Class] the object to define methods or ivars on
    def initialize(target)
      @target = normalize_target(target)
      @defined_methods = Hash.new { |h, k| h[k] = Set.new }
    end

    # Returns whether the current target is a module (but not a class),
    # indicating that attribute definitions should be deferred.
    #
    # Used to avoid premature method definitions in shared module contexts.
    #
    # @return [Boolean] true if the target is a non-class module
    def defer_definitions?
      @target.is_a?(Module) && !@target.is_a?(Class)
    end

    # Ensures that the target has support for deferred attribute definitions.
    #
    # This is used by DSLs that include attribute modules but delay application
    # until later (e.g., during subclassing or inclusion).
    #
    # @return [void]
    def ensure_deferred_support!
      return if @target < Cattri::DeferredAttributes

      @target.extend(Cattri::DeferredAttributes)
    end

    # Returns the full list of modules and classes that may define or inherit
    # attributes, including ancestors and included modules.
    #
    # @return [Array<Module>] unique ordered list of definition sources
    def attribute_sources
      ([@target] + @target.ancestors + @target.singleton_class.included_modules).uniq
    end

    # Removes all methods previously defined for the given attribute.
    #
    # This ensures clean redefinition by removing the method from the actual
    # target and clearing the internal registry.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def clear_defined_methods_for!(attribute)
      @defined_methods[attribute.name].each do |method_name|
        target = target_for(attribute)
        target.remove_method(method_name) rescue nil # rubocop:disable Style/RescueModifier
      end

      @defined_methods[attribute.name].clear
    end

    # Determines if a method is already defined on the target.
    #
    # This only checks methods defined directly on the target class or singleton—
    # inherited methods are ignored. This prevents false conflicts from ancestors.
    #
    # Also checks the internal registry of explicitly defined methods.
    #
    # @param attribute [Cattri::Attribute]
    # @param name [String, Symbol, nil] the method name to check (defaults to attribute name)
    # @return [Boolean]
    def method_defined?(attribute, name: nil)
      name = (name || attribute.name).to_sym
      target = target_for(attribute)

      defined_locally = (
        target.public_instance_methods(false) +
          target.protected_instance_methods(false) +
          target.private_instance_methods(false)
      )

      defined_locally.include?(name) || @defined_methods[attribute.name].include?(name)
    end

    # Defines a method for the attribute on the appropriate target (class or instance).
    #
    # If a method with the same name is already defined locally, this raises
    # a {Cattri::MethodDefinedError} unless `attribute[:force]` is true.
    #
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol, String, nil]
    # @yield the method body
    # @raise [Cattri::AttributeDefinitionError, Cattri::MethodDefinedError]
    # @return [void]
    def define_method(attribute, name: nil, &block)
      name = (name || attribute.name).to_sym
      target = target_for(attribute)

      raise Cattri::MethodDefinedError.new(name, target) if method_defined?(attribute, name: name) && !attribute[:force]

      define_method!(target, attribute, name, &block)
    end

    private

    # Normalizes the target to avoid defining methods on a singleton class directly.
    #
    # This ensures consistent method definition on the class/module level.
    #
    # @param target [Object]
    # @return [Class, Module]
    def normalize_target(target)
      return target unless singleton_class?(target)

      target.superclass || target
    end

    # Determines if the object is a singleton class.
    #
    # @param target [Object]
    # @return [Boolean]
    def singleton_class?(target)
      target.singleton_class?
    rescue StandardError
      target.to_s.start_with?("#<Class:")
    end

    # Force-defines a method on the given target.
    #
    # This method bypasses definition guards and directly installs the method.
    # It updates internal tracking and applies visibility settings.
    #
    # @param target [Module]
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol]
    # @yield method implementation
    # @raise [Cattri::AttributeDefinitionError]
    # @return [void]
    def define_method!(target, attribute, name, &block)
      target.class_eval { define_method(name, &block) }
      @defined_methods[attribute.name] << name

      apply_access(target, name, attribute)
    rescue StandardError => e
      raise Cattri::AttributeDefinitionError.new(target, attribute, e)
    end

    # Determines the correct context for defining a method based on attribute type.
    #
    # @param attribute [Cattri::Attribute]
    # @return [Module]
    def target_for(attribute)
      attribute.class_level? ? @target.singleton_class : @target
    end

    # Validates and coerces the given access level to a supported visibility.
    #
    # Defaults to `:public` if not provided or invalid.
    #
    # @param access [Symbol, String, nil]
    # @return [Symbol]
    def resolve_access(access)
      access = (access || :public).to_sym
      return access if ACCESS_LEVELS.include?(access)

      warn "[Cattri] `#{access.inspect}` is not a supported access level, defaulting to :public"
      :public
    end

    # Applies access visibility to the given method on the current target.
    #
    # Skips application for public methods.
    #
    # @param target [Module]
    # @param name [Symbol]
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def apply_access(target, name, attribute)
      return if attribute.public?

      access = resolve_access(attribute[:access])
      Module.instance_method(access).bind(target).call(name)
    end
  end
end
