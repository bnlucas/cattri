# frozen_string_literal: true

require_relative "error"
require_relative "helpers"

module Cattri
  # Provides a DSL for defining class-level attributes with support for:
  #
  # - Static or dynamic default values
  # - Optional coercion via setter blocks
  # - Optional instance-level readers
  # - Read-only attribute enforcement
  # - Inheritance-safe duplication
  # - Attribute locking to prevent mutation in subclasses
  #
  # This module is designed for advanced metaprogramming needs such as DSL builders,
  # configuration objects, and plugin systems that require reusable and introspectable
  # class-level state.
  #
  # @example
  #   class MyClass
  #     extend Cattri::ClassAttributes
  #
  #     cattr :format, default: :json
  #     cattr_reader :version, default: "1.0.0"
  #     cattr :enabled, default: true do |value|
  #       !!value
  #     end
  #   end
  #
  #   MyClass.format        # => :json
  #   MyClass.format :xml
  #   MyClass.format        # => :xml
  #   MyClass.version       # => "1.0.0"
  #
  #   instance = MyClass.new
  #   instance.format       # => :xml
  module ClassAttributes
    include Cattri::Helpers

    # Default options applied to all class-level attributes.
    DEFAULT_OPTIONS = { access: :public, default: nil, readonly: false, instance_reader: true }.freeze

    # Defines a class-level attribute with optional default, coercion, and reader access.
    #
    # @param name [Symbol] the attribute name
    # @param options [Hash] additional attribute options
    # @option options [Object, Proc] :default the default value or callable
    # @option options [Symbol] :access the method access level, defaults to :public (:public, :protected, :private)
    # @option options [Boolean] :readonly whether the attribute is read-only
    # @option options [Boolean] :instance_reader whether to define an instance-level reader
    # @yield [*args] Optional setter block for custom coercion
    # @raise [Cattri::Error] if attribute is already defined
    # @return [void]
    def class_attribute(name, **options, &block)
      define_inheritance unless respond_to?(:__cattri_class_attributes)

      name, definition = define_attribute(self, name, options, block, DEFAULT_OPTIONS)
      raise Cattri::Error, "Class attribute `#{name}` already defined" if class_attribute_defined?(name)

      __cattri_class_attributes[name] = definition

      define_accessor(name, definition)
      define_instance_reader(name) if definition[:instance_reader]

      apply_access(self, definition)
    end

    # Defines a read-only class attribute (no writer).
    #
    # @param name [Symbol]
    # @param options [Hash]
    # @return [void]
    def class_attribute_reader(name, **options)
      class_attribute(name, readonly: true, **options)
    end

    # Returns all defined class-level attribute names.
    #
    # @return [Array<Symbol>]
    def class_attributes
      __cattri_class_attributes.keys
    end

    # Checks whether a class-level attribute is defined.
    #
    # @param name [Symbol]
    # @return [Boolean]
    def class_attribute_defined?(name)
      __cattri_class_attributes.key?(name.to_sym)
    end

    # Returns metadata for a given class-level attribute.
    #
    # @param name [Symbol]
    # @return [Hash, nil]
    def class_attribute_definition(name)
      __cattri_class_attributes[name.to_sym]
    end

    # Resets all defined class attributes to their default values.
    #
    # @return [void]
    def reset_class_attributes!
      reset_attributes!(self, __cattri_class_attributes.values)
    end

    # Resets a single class attribute to its default value.
    #
    # @param name [Symbol]
    # @return [void]
    def reset_class_attribute!(name)
      definition = __cattri_class_attributes[name]
      return unless definition

      reset_attributes!(self, [definition])
    end

    # alias lock_cattrs! lock_class_attributes!
    # alias cattrs_locked? class_attributes_locked?

    # @!method cattr(name, **options, &block)
    #   Alias for {.class_attribute}
    #   @see .class_attribute
    alias cattr class_attribute

    # @!method cattr_accessor(name, **options, &block)
    #   Alias for {.class_attribute}
    #   @see .class_attribute
    alias cattr_accessor class_attribute

    # @!method cattr_reader(name, **options)
    #   Alias for {.class_attribute_reader}
    #   @see .class_attribute_reader
    alias cattr_reader class_attribute_reader

    # @!method cattrs
    #   @return [Array<Symbol>] all defined class attribute names
    #   @see .class_attributes
    alias cattrs class_attributes

    # @!method cattr_defined?(name)
    #   @return [Boolean] whether the given attribute has been defined
    #   @see .class_attribute_defined?
    alias cattr_defined? class_attribute_defined?

    # @!method cattr_for(name)
    #   @return [Hash, nil] the internal metadata hash for a defined attribute
    #   @see .class_attribute_for
    alias cattr_definition class_attribute_definition

    # @!method reset_cattrs!
    #   Resets all class attributes to their default values.
    #   @see .reset_class_attributes!
    alias reset_cattrs! reset_class_attributes!

    # @!method reset_cattr!(name)
    #   Resets a specific class attribute to its default value.
    #   @see .reset_class_attribute!
    alias reset_cattr! reset_class_attribute!

    private

    # Defines class-level inheritance behavior for declared attributes.
    #
    # @return [void]
    def define_inheritance
      unless singleton_class.method_defined?(:__cattri_class_attributes)
        define_singleton_method(:__cattri_class_attributes) { @__cattri_class_attributes ||= {} }
      end

      define_singleton_method(:inherited) do |subclass|
        super(subclass)
        subclass_attributes = {}

        __cattri_class_attributes.each do |name, definition|
          apply_attribute!(subclass, subclass_attributes, name, definition)
        end

        subclass.instance_variable_set(:@__cattri_class_attributes, subclass_attributes)
      end
    end

    # Defines the primary accessor method on the class.
    #
    # @param name [Symbol]
    # @param definition [Hash]
    # @return [void]
    def define_accessor(name, definition)
      ivar = definition[:ivar]

      define_singleton_method(name) do |*args, **kwargs|
        readonly = readonly_call?(args, kwargs) || definition[:readonly]
        return apply_readonly(ivar, definition[:default]) if readonly

        instance_variable_set(ivar, definition[:setter].call(*args, **kwargs))
      end

      return if definition[:readonly]

      define_singleton_method("#{name}=") do |value|
        instance_variable_set(ivar, definition[:setter].call(value))
      end
    end

    # Defines an instance-level reader that delegates to the class-level method.
    #
    # @param name [Symbol]
    # @return [void]
    def define_instance_reader(name)
      define_method(name) { self.class.__send__(name) }
    end

    # Applies the default value for a read-only call.
    #
    # @param ivar [Symbol]
    # @param default [Proc]
    # @return [Object]
    def apply_readonly(ivar, default)
      return instance_variable_get(ivar) if instance_variable_defined?(ivar)

      value = default.call
      instance_variable_set(ivar, value)
    end

    # Applies inherited attribute definitions to a subclass.
    #
    # @param subclass [Class]
    # @param attributes [Hash]
    # @param name [Symbol]
    # @param definition [Hash]
    # @return [void]
    def apply_attribute!(subclass, attributes, name, definition)
      value = instance_variable_get(definition[:ivar])
      value = value.dup rescue value # rubocop:disable Style/RescueModifier

      subclass.instance_variable_set(definition[:ivar], value)
      attributes[name] = definition
    end

    # Determines if the method call should be treated as read-only access.
    #
    # @param args [Array]
    # @param kwargs [Hash]
    # @return [Boolean]
    def readonly_call?(args, kwargs)
      args.empty? && kwargs.empty?
    end
  end
end
