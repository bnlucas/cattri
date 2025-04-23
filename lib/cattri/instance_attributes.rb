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
      # Defines one or more instance-level attributes with optional default and coercion.
      #
      # This method supports defining multiple attributes at once, provided they share the same options.
      # If a block is given, only one attribute may be defined to avoid ambiguity.
      #
      # @example Define multiple attributes with shared defaults
      #   iattr :foo, :bar, default: []
      #
      # @example Define a single attribute with coercion
      #   iattr :level do |val|
      #     Integer(val)
      #   end
      #
      # @param names [Array<Symbol | String>] the names of the attributes to define
      # @param options [Hash] additional options like `:default`, `:reader`, `:writer`
      # @option options [Object, Proc] :default the default value or lambda
      # @option options [Boolean] :reader whether to define a reader method (default: true)
      # @option options [Boolean] :writer whether to define a writer method (default: true)
      # @option options [Symbol] :access method visibility (:public, :protected, :private)
      # @yieldparam value [Object] optional custom coercion logic for the setter
      # @raise [Cattri::AttributeError] or its subclasses, including `Cattri::AttributeDefinedError` or
      #   `Cattri::AttributeDefinitionError` if defining the attribute fails (e.g., if the attribute is
      #    already defined or an error occurs while defining methods)
      # @return [void]
      def instance_attribute(*names, **options, &block)
        raise Cattri::AmbiguousBlockError if names.size > 1 && block_given?

        names.each { |name| define_instance_attribute(name, options, block) }
      end

      # Defines a read-only instance-level attribute.
      #
      # Equivalent to `instance_attribute(..., writer: false)`
      #
      # @param names [Array<Symbol | String>] the names of the attributes to define
      # @param options [Hash] additional options like `:default`, `:reader`, `:writer`
      # @option options [Object, Proc] :default the default value or lambda
      # @option options [Boolean] :reader whether to define a reader method (default: true)
      # @option options [Symbol] :access method visibility (:public, :protected, :private)
      # @yieldparam value [Object] optional custom coercion logic for the setter
      # @raise [Cattri::AttributeError] or its subclasses, including `Cattri::AttributeDefinedError` or
      #   `Cattri::AttributeDefinitionError` if defining the attribute fails (e.g., if the attribute is
      #    already defined or an error occurs while defining methods)
      # @return [void]
      def instance_attribute_reader(*names, **options)
        instance_attribute(*names, **options, writer: false)
      end

      # Defines a write-only instance-level attribute.
      #
      # Equivalent to `instance_attribute(..., reader: false)`
      #
      # @param names [Array<Symbol | String>] the names of the attributes to define
      # @param options [Hash] additional options like `:default`, `:reader`, `:writer`
      # @option options [Object, Proc] :default the default value or lambda
      # @option options [Boolean] :writer whether to define a writer method (default: true)
      # @option options [Symbol] :access method visibility (:public, :protected, :private)
      # @yieldparam value [Object] optional custom coercion logic for the setter
      # @raise [Cattri::AttributeError] or its subclasses, including `Cattri::AttributeDefinedError` or
      #   `Cattri::AttributeDefinitionError` if defining the attribute fails (e.g., if the attribute is
      #    already defined or an error occurs while defining methods)
      # @return [void]
      def instance_attribute_writer(*names, **options, &block)
        instance_attribute(*names, **options.merge(reader: false), &block)
      end

      # Updates the setter behavior of an existing instance-level attribute.
      #
      # This allows coercion logic to be defined or overridden after the attribute
      # has been declared using `iattr`, as long as the writer method exists.
      #
      # @example Add coercion to an existing attribute
      #   iattr :format
      #   iattr_setter :format do |val|
      #     val.to_s.downcase.to_sym
      #   end
      #
      # @param name [Symbol, String] the name of the attribute
      # @yieldparam value [Object] the value passed to the setter
      # @yieldreturn [Object] the coerced value to be assigned
      # @raise [Cattri::AttributeNotDefinedError] if the attribute is not defined or the writer method does not exist
      # @raise [Cattri::AttributeDefinitionError] if method redefinition fails
      # @return [void]
      def instance_attribute_setter(name, &block)
        attribute = __cattri_instance_attributes[name.to_sym]

        raise Cattri::AttributeNotDefinedError.new(:instance, name) if attribute.nil?
        raise Cattri::AttributeError, "Cannot define setter for readonly attribute :#{name}" unless attribute[:writer]

        attribute.instance_variable_set(:@setter, attribute.send(:normalize_setter, block))
        Cattri::AttributeDefiner.define_writer!(attribute, context)
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

      # @!method iattr_setter(name, &block)
      #   Alias for {#instance_attribute_setter}
      alias iattr_setter instance_attribute_setter

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

      # Defines a single instance-level attribute.
      #
      # This is the internal implementation used by {.instance_attribute} and its aliases.
      # It creates a `Cattri::Attribute`, registers it, and defines the appropriate
      # reader and/or writer methods on the class.
      #
      # @param name [Symbol, String] the attribute name
      # @param options [Hash] additional options for the attribute
      # @param block [Proc, nil] optional setter coercion logic
      #
      # @raise [Cattri::AttributeDefinedError] if the attribute has already been defined
      # @raise [Cattri::AttributeDefinitionError] if method definition fails
      #
      # @return [void]
      def define_instance_attribute(name, options, block)
        options[:access] ||= __cattri_visibility
        attribute = Cattri::Attribute.new(name, :instance, options, block)

        raise Cattri::AttributeDefinedError.new(:instance, name) if instance_attribute_defined?(attribute.name)

        begin
          __cattri_instance_attributes[name.to_sym] = attribute
          Cattri::AttributeDefiner.define_accessor(attribute, context)
        rescue StandardError => e
          raise Cattri::AttributeDefinitionError.new(self, attribute, e)
        end
      end

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
