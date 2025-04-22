# frozen_string_literal: true

require_relative "attribute"
require_relative "context"
require_relative "attribute_definer"
require_relative "visibility"

module Cattri
  # Mixin that provides support for defining class-level attributes.
  #
  # This module is intended to be extended onto a class and provides a DSL
  # for defining configuration-style attributes at the class level using `cattr`.
  #
  # Features:
  # - Default values (static, frozen, or callable)
  # - Optional coercion via setter blocks
  # - Optional instance-level readers
  # - Visibility enforcement (`:public`, `:protected`, `:private`)
  #
  # Class attributes are stored internally as `Cattri::Attribute` instances and
  # values are memoized using class-level instance variables.
  module ClassAttributes
    # Defines a class-level attribute with optional default, coercion, and reader access.
    #
    # @param name [Symbol] the attribute name
    # @param options [Hash] additional attribute options
    # @option options [Object, Proc] :default the default value or lambda
    # @option options [Boolean] :readonly whether the attribute is read-only
    # @option options [Boolean] :instance_reader whether to define an instance-level reader (default: true)
    # @option options [Symbol] :access visibility level (:public, :protected, :private)
    # @yieldparam value [Object] an optional custom setter block
    # @raise [Cattri::AttributeError] or its subclasses, including `Cattri::AttributeDefinedError` or
    #   `Cattri::AttributeDefinitionError` if defining the attribute fails (e.g., if the attribute is
    #    already defined or an error occurs while defining methods)
    def class_attribute(name, **options, &block)
      options[:access] ||= __cattri_visibility
      attribute = Cattri::Attribute.new(name, :class, options, block)

      raise Cattri::AttributeDefinedError, attribute if class_attribute_defined?(attribute.name)

      begin
        __cattri_class_attributes[name] = attribute

        Cattri::AttributeDefiner.define_callable_accessor(attribute, context)
        Cattri::AttributeDefiner.define_instance_level_reader(attribute, context) if attribute[:instance_reader]
      rescue StandardError => e
        raise Cattri::AttributeDefinitionError.new(self, attribute, e)
      end
    end

    # Defines a read-only class attribute.
    #
    # Equivalent to calling `class_attribute(name, readonly: true, ...)`
    #
    # @param name [Symbol]
    # @param options [Hash]
    # @return [void]
    def class_attribute_reader(name, **options)
      class_attribute(name, readonly: true, **options)
    end

    # Returns a list of defined class attribute names.
    #
    # @return [Array<Symbol>]
    def class_attributes
      __cattri_class_attributes.keys
    end

    # Checks whether a class attribute has been defined.
    #
    # @param name [Symbol]
    # @return [Boolean]
    def class_attribute_defined?(name)
      __cattri_class_attributes.key?(name.to_sym)
    end

    # Returns the full attribute definition object.
    #
    # @param name [Symbol]
    # @return [Cattri::Attribute, nil]
    def class_attribute_definition(name)
      __cattri_class_attributes[name.to_sym]
    end

    # @!method cattr(name, **options, &block)
    #   Alias for {.class_attribute}
    #   @see #class_attribute
    alias cattr class_attribute

    # @!method cattr_accessor(name, **options, &block)
    #   Alias for {.class_attribute}
    #   @see #class_attribute
    alias cattr_accessor class_attribute

    # @!method cattr_reader(name, **options)
    #   Alias for {.class_attribute_reader}
    #   @see #class_attribute_reader
    alias cattr_reader class_attribute_reader

    # @!method cattrs
    #   Alias for {.class_attributes}
    #   @return [Array<Symbol>]
    alias cattrs class_attributes

    # @!method cattr_defined?(name)
    #   Alias for {.class_attribute_defined?}
    #   @param name [Symbol]
    #   @return [Boolean]
    alias cattr_defined? class_attribute_defined?

    # @!method cattr_definition(name)
    #   Alias for {.class_attribute_definition}
    #   @param name [Symbol]
    #   @return [Cattri::Attribute, nil]
    alias cattr_definition class_attribute_definition

    private

    # Internal registry of defined class-level attributes.
    #
    # @return [Hash{Symbol => Cattri::Attribute}]
    def __cattri_class_attributes
      @__cattri_class_attributes ||= {}
    end

    # Context object used to define accessors with scoped visibility.
    #
    # @return [Cattri::Context]
    # :nocov:
    def context
      @context ||= Context.new(self)
    end
    # :nocov:
  end
end
