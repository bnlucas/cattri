# frozen_string_literal: true

module Cattri
  # Internal support utilities for Cattri modules.
  #
  # Provides shared logic for safe default handling, attribute definition, and
  # consistent reset behavior across class-level and instance-level attributes.
  #
  # This module is intended for internal use only and is included by both
  # Cattri::ClassAttributes and Cattri::InstanceAttributes.
  module Helpers
    # A list of immutable Ruby types that are safe to reuse directly without duplication.
    #
    # These types are treated as-is when used as default values.
    #
    # @return [Array<Class>]
    SAFE_VALUE_TYPES = [Numeric, Symbol, TrueClass, FalseClass, NilClass].freeze

    # A list of allowed method access levels.
    #
    # @return [Array<Symbol>]
    ACCESS_LEVELS = %i[public protected private].freeze

    protected

    # Defines an attribute structure used internally for accessors.
    #
    # Combines the caller's options with normalized default and setter logic,
    # and attaches a consistent `@ivar` key for storage.
    #
    # Resolves the current access scope of `target` if `access` is not provided in the options.
    # If an invalid access level is provided, a warning is triggered and the attribute is
    # set to :public.
    #
    # @param target [Class, Module] The class or module the attribute is being defined on
    # @param name [Symbol, String] The attribute name
    # @param options [Hash] The caller-provided options (e.g., `:default`, `:readonly`)
    # @param block [Proc, nil] Optional setter block
    # @param defaults [Hash] A set of fallback/default values to merge in
    # @return [Array] Normalized name and attribute definition hash
    def define_attribute(target, name, options, block, defaults)
      options[:access] = define_attribute_access(target, options[:access])
      options[:default] = normalize_default(options[:default])
      options[:setter] = block || lambda { |*args, **kwargs|
        return kwargs unless kwargs.empty?
        return args.first if args.length == 1

        args
      }

      name = name.to_sym
      [name, defaults.merge(name: name, ivar: :"@#{name}", **options).freeze]
    end

    # Defines the attribute's access level. If an access value is provided, this will be respected
    # as long as its valid.
    #
    # If the access provided is not valid, in ACCESS_LEVELS, it will be defaulted to :public with
    # warning message being triggered.
    #
    # If no access is provided, it will use the target's current access scope.
    #
    # @see .resolve_access_scope
    #
    # @param target [Class, Module] The class or module the attribute is being defined on
    # @param access [Symbol, nil] The access level provided
    # @return [Symbol] The access level provided or the resolved level.
    def define_attribute_access(target, access)
      access = access&.to_sym
      return access if access && ACCESS_LEVELS.include?(access)

      unless access.nil? || ACCESS_LEVELS.include?(access.to_sym)
        warn "[Cattri] `#{access.inspect}` is not a supported access level, defaulting to :public"
        return :public
      end

      resolve_access_scope(target)
    end

    # Wraps static default values in lambdas to ensure safety.
    #
    # If the value is already callable, it is returned as-is.
    # If the value is immutable, it is wrapped directly.
    # Otherwise, it is wrapped with `.dup` for safe reuse.
    #
    # @param default [Object, Proc, nil] The user-provided default value
    # @return [Proc] A proc that returns a safe default value
    def normalize_default(default)
      return default if default.respond_to?(:call)
      return -> { default } if default.frozen? || SAFE_VALUE_TYPES.any? { |type| default.is_a?(type) }

      -> { default.dup }
    end

    # Resets a set of attribute definitions on a target object.
    #
    # Used to restore class or instance attributes to their configured default values.
    #
    # @param target [Class, Module] The class or module the attribute is being defined on
    # @param attribute_definitions [Enumerable<Hash>] A list of attribute definition hashes
    # @return [void]
    def reset_attributes!(target, attribute_definitions)
      attribute_definitions.each do |definition|
        target.instance_variable_set(
          definition[:ivar],
          definition[:default].call
        )
      end
    end

    # Resolves the current access scope in the class.
    #
    # class CattriClass
    #   public
    #   cattr :public_attr
    #
    #   protected
    #   cattr :protected_attr
    #
    #   private
    #   cattr :private_attr
    # end
    #
    # @param target [Class, Module] The class or module the attribute is being defined on
    # @return [Symbol] The current access scope
    def resolve_access_scope(target)
      marker = :__cattri_access_scope__
      begin
        target.module_eval { attr_reader marker }

        return :private if target.private_method_defined?(marker)
        return :protected if target.protected_instance_methods.include?(marker)

        :public
      ensure
        target.send(:remove_method, marker) rescue nil # rubocop:disable Style/RescueModifier
      end
    end

    # Applies access levels (public, protected, private) to the defined attribute methods.
    #
    # @param target [Class, Module] The class or module the attribute is being defined on
    # @param attribute_definition [Hash] The attribute definition hash
    # @return [void]
    def apply_access(target, attribute_definition)
      return unless apply_access?(attribute_definition)

      access = attribute_definition[:access]
      method_names = [attribute_definition[:name], "#{attribute_definition[:name]}="]

      method_names.each do |method_name|
        next unless target.method_defined?(method_name)

        target.send(access, method_name)
      rescue NameError => e
        warn "[Cattri] Warning: Could not apply `#{access}` to `#{method_name}` on #{target}: #{e.message}"
      end
    end

    # Determine if applying access is required or not.
    #
    # - If the definition has `access: :public`, we can skip this as all methods are public by default.
    # - If `attribute_definitions[:name]` is nil, we cannot apply access to missing methods.
    # - If `attribute_definition[:access]` is not a valid access level, we cannot apply access.
    #
    # @param attribute_definition [Hash] The attribute definition hash
    # @return [Boolean] true if access should be applied, otherwise false.
    def apply_access?(attribute_definition)
      return false if attribute_definition[:access] == :public || attribute_definition[:name].nil?
      return false unless ACCESS_LEVELS.include?(attribute_definition[:access])

      true
    end
  end
end
