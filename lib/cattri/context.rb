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
  class Context
    # Allowed Ruby visibility levels for methods.
    ACCESS_LEVELS = %i[public protected private].freeze
    private_constant :ACCESS_LEVELS

    # @return [Module, Class] the receiver to which accessors will be added
    attr_reader :target

    # Initializes a new context wrapper around the given target.
    #
    # @param target [Module, Class] the object to define methods or ivars on
    def initialize(target)
      @target = target
      @defined_methods = Set.new
    end

    # Returns the singleton class of the target.
    #
    # This is used to define methods on the class itself (not its instances).
    #
    # @return [Class]
    def singleton
      @target.singleton_class
    end

    # Checks whether a method is already defined on the target.
    #
    # This includes public, protected, private, and previously defined methods
    # via this context (tracked in `@defined_methods`).
    #
    # @param method [String, Symbol]
    # @return [Boolean]
    def method_defined?(method)
      @target.method_defined?(method) ||
        @target.private_method_defined?(method) ||
        @target.protected_method_defined?(method) ||
        @defined_methods.include?(method.to_sym)
    end

    # Defines a method on the appropriate context (class or singleton).
    #
    # If the method already exists, it is not redefined. Visibility is applied
    # according to the attribute's `:access` setting (defaulting to `:public`).
    #
    # @param attribute [Cattri::Attribute]
    # @param name [Symbol, nil] optional method name override
    # @yield the method implementation
    # @raise [Cattri::AttributeDefinitionError] if method definition fails
    # @return [void]
    def define_method(attribute, name: nil, &block)
      name = (name || attribute.name).to_sym
      return if method_defined?(name)

      target = target_for(attribute)

      begin
        target.define_method(name, &block)
        @defined_methods << name
        apply_access(name, attribute)
      rescue StandardError => e
        raise Cattri::AttributeDefinitionError.new(target, attribute, e)
      end
    end

    # Checks whether the target has the given instance variable.
    #
    # @param name [Symbol, String]
    # @return [Boolean]
    def ivar_defined?(name)
      @target.instance_variable_defined?(sanitize_ivar(name))
    end

    # Retrieves the value of the specified instance variable on the target.
    #
    # @param name [Symbol, String]
    # @return [Object]
    def ivar_get(name)
      @target.instance_variable_get(sanitize_ivar(name))
    end

    # Assigns a value to the specified instance variable on the target.
    #
    # @param name [Symbol, String]
    # @param value [Object]
    # @return [void]
    def ivar_set(name, value)
      @target.instance_variable_set(sanitize_ivar(name), value)
    end

    # Memoizes a value in the instance variable only if not already defined.
    #
    # @param name [Symbol, String]
    # @param value [Object]
    # @return [Object] the existing or assigned value
    def ivar_memoize(name, value)
      return ivar_get(name) if ivar_defined?(name)

      ivar_set(name, value)
    end

    private

    # Selects the correct definition target based on attribute type.
    #
    # @param attribute [Cattri::Attribute]
    # @return [Module] either the target or its singleton class
    def target_for(attribute)
      attribute.class_level? ? singleton : @target
    end

    # Validates and normalizes access level.
    #
    # @param access [Symbol, String, nil]
    # @return [Symbol] a valid visibility level
    def validate_access(access)
      access = (access || :public).to_sym
      return access if ACCESS_LEVELS.include?(access)

      warn "[Cattri] `#{access.inspect}` is not a supported access level, defaulting to :public"
      :public
    end

    # Applies method visibility to a newly defined method.
    #
    # @param method_name [Symbol]
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def apply_access(method_name, attribute)
      return if attribute.public?

      access = validate_access(attribute[:access])
      Module.instance_method(access).bind(@target).call(method_name)
    end

    # Ensures consistent formatting for ivar keys.
    #
    # @param name [Symbol, String]
    # @return [Symbol]
    def sanitize_ivar(name)
      :"@#{name.to_s.delete_prefix("@")}"
    end
  end
end
