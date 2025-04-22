# frozen_string_literal: true

require_relative "attribute_definer"

module Cattri
  # Mixin that provides support for defining instance-level attributes.
  #
  # This module is included into a class (via `include Cattri`) and exposes
  # a DSL similar to `attr_accessor`, with enhancements:
  #
  # - Lazy or static default values
  # - Coercion via custom setter blocks
  # - Visibility control (`:public`, `:protected`, `:private`)
  # - Read-only or write-only support
  #
  # Each defined attribute is stored as metadata and linked to a reader and/or writer.
  # Values are accessed and stored via standard instance variables.
  module InstanceAttributes
    # Hook called when this module is included into a class.
    #
    # @param base [Class]
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Defines instance-level attribute DSL methods.
    module ClassMethods
      # Defines an instance-level attribute with optional default and coercion.
      #
      # @param name [Symbol, String] the name of the attribute
      # @param options [Hash] additional options like `:default`, `:reader`, `:writer`
      # @option options [Object, Proc] :default the default value or lambda
      # @option options [Boolean] :reader whether to define a reader method (default: true)
      # @option options [Boolean] :writer whether to define a writer method (default: true)
      # @option options [Symbol] :access method visibility (:public, :protected, :private)
      # @yieldparam value [Object] optional custom coercion logic for the setter
      # @raise [Cattri::AttributeError] or its subclasses, including `Cattri::AttributeDefinedError` or
      #   `Cattri::AttributeDefinitionError` if defining the attribute fails (e.g., if the attribute is
      #    already defined or an error occurs while defining methods)
      def instance_attribute(name, **options, &block)
        options[:access] ||= __cattri_visibility
        attribute = Cattri::Attribute.new(name, :instance, options, block)

        raise Cattri::AttributeDefinedError, attribute if instance_attribute_defined?(attribute.name)

        begin
          __cattri_instance_attributes[name.to_sym] = attribute
          Cattri::AttributeDefiner.define_accessor(attribute, context)
        rescue StandardError => e
          raise Cattri::AttributeDefinitionError.new(self, attribute, e)
        end
      end

      # Defines a read-only instance-level attribute.
      #
      # Equivalent to `instance_attribute(..., writer: false)`
      #
      # @param name [Symbol, String]
      # @param options [Hash]
      # @return [void]
      def instance_attribute_reader(name, **options)
        instance_attribute(name, writer: false, **options)
      end

      # Defines a write-only instance-level attribute.
      #
      # Equivalent to `instance_attribute(..., reader: false)`
      #
      # @param name [Symbol, String]
      # @param options [Hash]
      # @yieldparam value [Object] optional coercion logic
      # @return [void]
      def instance_attribute_writer(name, **options, &block)
        instance_attribute(name, reader: false, **options, &block)
      end

      # Returns a list of defined instance-level attribute names.
      #
      # @return [Array<Symbol>]
      def instance_attributes
        __cattri_instance_attributes.keys
      end

      # Checks if an instance-level attribute has been defined.
      #
      # @param name [Symbol, String]
      # @return [Boolean]
      def instance_attribute_defined?(name)
        __cattri_instance_attributes.key?(name.to_sym)
      end

      # Returns the full attribute definition for a given name.
      #
      # @param name [Symbol, String]
      # @return [Cattri::Attribute, nil]
      def instance_attribute_definition(name)
        __cattri_instance_attributes[name.to_sym]
      end

      # @!method iattr(name, **options, &block)
      #   Alias for {#instance_attribute}
      alias iattr instance_attribute

      # @!method iattr_accessor(name, **options, &block)
      #   Alias for {#instance_attribute}
      alias iattr_accessor instance_attribute

      # @!method iattr_reader(name, **options)
      #   Alias for {#instance_attribute_reader}
      alias iattr_reader instance_attribute_reader

      # @!method iattr_writer(name, **options, &block)
      #   Alias for {#instance_attribute_writer}
      alias iattr_writer instance_attribute_writer

      # @!method iattrs
      #   Alias for {#instance_attributes}
      alias iattrs instance_attributes

      # @!method iattr_defined?(name)
      #   Alias for {#instance_attribute_defined?}
      alias iattr_defined? instance_attribute_defined?

      # @!method iattr_definition(name)
      #   Alias for {#instance_attribute_definition}
      alias iattr_definition instance_attribute_definition

      private

      # Internal registry of instance attributes defined on the class.
      #
      # @return [Hash{Symbol => Cattri::Attribute}]
      def __cattri_instance_attributes
        @__cattri_instance_attributes ||= {}
      end

      # Returns the context used to define methods for this class.
      #
      # Used internally to encapsulate method definition and visibility rules.
      #
      # @return [Cattri::Context]
      # :nocov:
      def context
        @context ||= Context.new(self)
      end
      # :nocov:
    end
  end
end
