# frozen_string_literal: true

module Cattri
  # Provides a DSL for defining instance-level attributes with support for:
  #
  # - Default values (static or callable)
  # - Optional reader/writer method generation
  # - Custom coercion logic for writers
  # - Full attribute metadata access and reset capabilities
  #
  # This module is designed for mixin into classes or modules that want to offer
  # configurable instance attributes (e.g., plugin systems, DTOs, DSLs).
  #
  # Example:
  #
  #   class MyObject
  #     extend Cattri::InstanceAttributes
  #
  #     iattr :name, default: "anonymous"
  #     iattr_writer :age, default: 0 do |v|
  #       Integer(v)
  #     end
  #   end
  #
  #   obj = MyObject.new
  #   obj.name # => "anonymous"
  #   obj.age = "42"
  #   obj.instance_variable_get(:@age) # => 42
  module InstanceAttributes
    include Cattri::Helpers

    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods for defining instance attributes
    module ClassMethods
      include Cattri::Helpers

      # Default options for all instance attributes
      DEFAULT_OPTIONS = { default: nil, reader: true, writer: true }.freeze

      # Defines a new instance-level attribute with optional default and coercion.
      #
      # @param name [Symbol, String] the name of the attribute
      # @param options [Hash] additional options like `:default`, `:reader`, `:writer`
      # @option options [Object, Proc] :default the default value or proc returning the value
      # @option options [Boolean] :reader whether to define a reader method (default: true)
      # @option options [Boolean] :writer whether to define a writer method (default: true)
      # @yield [value] optional coercion logic for the writer
      # @return [void]
      def instance_attribute(name, **options, &block)
        name, definition = define_attribute(name, options, block, DEFAULT_OPTIONS)
        __cattri_instance_attributes[name] = definition

        define_reader(name, definition) if options.fetch(:reader, true)
        define_writer(name, definition) if options.fetch(:writer, true)
      end

      # Defines a read-only instance-level attribute.
      #
      # @param name [Symbol, String]
      # @param options [Hash]
      # @return [void]
      def instance_attribute_reader(name, **options)
        instance_attribute(name, writer: false, **options)
      end

      # Defines a write-only instance-level attribute.
      #
      # @param name [Symbol, String]
      # @param options [Hash]
      # @yield [value] coercion logic
      # @return [void]
      def instance_attribute_writer(name, **options, &block)
        instance_attribute(name, reader: false, **options, &block)
      end

      def __cattri_instance_attributes
        @__cattri_instance_attributes ||= {}
      end

      # Returns all defined instance-level attribute names.
      #
      # @return [Array<Symbol>]
      def instance_attributes
        __cattri_instance_attributes.keys
      end

      # Checks whether an instance attribute is defined.
      #
      # @param name [Symbol, String]
      # @return [Boolean]
      def instance_attribute_defined?(name)
        __cattri_instance_attributes.key?(name.to_sym)
      end

      # Fetches the full definition hash for a specific attribute.
      #
      # @param name [Symbol, String]
      # @return [Hash, nil]
      def instance_attribute_definition(name)
        __cattri_instance_attributes[name.to_sym]
      end

      # @!method iattr(name, **options, &block)
      #   Alias for {.instance_attribute}
      #   @see .instance_attribute
      alias iattr instance_attribute

      # @!method iattr_accessor(name, **options, &block)
      #   Alias for {.instance_attribute}
      #   @see .instance_attribute
      alias iattr_accessor instance_attribute

      # @!method iattr_reader(name, **options)
      #   Alias for {.instance_attribute_reader}
      #   @see .instance_attribute_reader
      alias iattr_reader instance_attribute_reader

      # @!method iattr_writer(name, **options, &block)
      #   Alias for {.instance_attribute_writer}
      #   @see .instance_attribute_writer
      alias iattr_writer instance_attribute_writer

      # @!method iattrs
      #   @return [Hash<Symbol, Hash>] all defined attributes
      #   @see .instance_attributes
      alias iattrs instance_attributes

      # @!method iattr_defined?(name)
      #   @return [Boolean]
      #   @see .instance_attribute_defined?
      alias iattr_defined? instance_attribute_defined?

      # @!method iattr_for(name)
      #   @return [Hash, nil]
      #   @see .instance_attribute_definition
      alias iattr_definition instance_attribute_definition

      private

      # Defines the reader method for an instance attribute.
      #
      # @param name [Symbol] attribute name
      # @param definition [Hash] full attribute definition
      def define_reader(name, definition)
        ivar = definition[:ivar]

        define_method(name) do
          return instance_variable_get(ivar) if instance_variable_defined?(ivar)

          value = definition[:default].call
          instance_variable_set(ivar, value)
        end
      end

      # Defines the writer method for an instance attribute.
      #
      # @param name [Symbol] attribute name
      # @param definition [Hash] full attribute definition
      def define_writer(name, definition)
        define_method("#{name}=") do |value|
          coerced_value = definition[:setter].call(value)
          instance_variable_set(definition[:ivar], coerced_value)
        end
      end
    end

    # Resets all defined attributes to their default values.
    #
    # @return [void]
    def reset_instance_attributes!
      reset_attributes!(self, self.class.__cattri_instance_attributes.values)
    end

    # Resets a specific attribute to its default value.
    #
    # @param name [Symbol, String]
    # @return [void]
    def reset_instance_attribute!(name)
      definition = self.class.__cattri_instance_attributes[name]
      return unless definition

      reset_attributes!(self, [definition])
    end

    # @!method reset_iattrs!
    #   @return [void]
    #   @see .reset_instance_attributes!
    alias reset_iattrs! reset_instance_attributes!

    # @!method reset_iattr!(name)
    #   @return [void]
    #   @see .reset_instance_attribute!
    alias reset_iattr! reset_instance_attribute!
  end
end
