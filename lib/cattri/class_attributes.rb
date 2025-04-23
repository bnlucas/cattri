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
    # Defines one or more class-level attributes with optional default, coercion, and reader access.
    #
    # This method supports defining multiple attributes at once, provided they share the same options.
    # If a block is given, only one attribute may be defined to avoid ambiguity.
    #
    # @example Define multiple attributes with shared options
    #   class_attribute :foo, :bar, default: 42
    #
    # @example Define a single attribute with a coercion block
    #   class_attribute :path do |val|
    #     Pathname(val)
    #   end
    #
    # @param names [Array<Symbol | String>] the names of the attributes to define
    # @param options [Hash] additional attribute options
    # @option options [Object, Proc] :default the default value or lambda
    # @option options [Boolean] :readonly whether the attribute is read-only
    # @option options [Boolean] :instance_reader whether to define an instance-level reader (default: true)
    # @option options [Symbol] :access visibility level (:public, :protected, :private)
    # @yieldparam value [Object] an optional custom setter block
    # @raise [Cattri::AttributeError] or its subclasses, including `Cattri::AttributeDefinedError` or
    #   `Cattri::AttributeDefinitionError` if defining the attribute fails (e.g., if the attribute is
    #    already defined or an error occurs while defining methods)
    # @return [void]
    def class_attribute(*names, **options, &block)
      raise Cattri::AmbiguousBlockError if names.size > 1 && block_given?

      names.each { |name| define_class_attribute(name, options, block) }
    end

    # Defines a read-only class attribute.
    #
    # Equivalent to calling `class_attribute(name, readonly: true, ...)`
    #
    # @param names [Array<Symbol | String>] the names of the attributes to define
    # @param options [Hash] additional attribute options
    # @option options [Object, Proc] :default the default value or lambda
    # @option options [Boolean] :readonly whether the attribute is read-only
    # @option options [Boolean] :instance_reader whether to define an instance-level reader (default: true)
    # @option options [Symbol] :access visibility level (:public, :protected, :private)
    # @raise [Cattri::AttributeError] or its subclasses, including `Cattri::AttributeDefinedError` or
    #   `Cattri::AttributeDefinitionError` if defining the attribute fails (e.g., if the attribute is
    #    already defined or an error occurs while defining methods)
    # @return [void]
    def class_attribute_reader(*names, **options)
      class_attribute(*names, **options, readonly: true)
    end

    # Updates the setter behavior of an existing class-level attribute.
    #
    # This allows coercion logic to be defined or overridden after the attribute
    # has been declared using `cattr`, as long as the writer method exists.
    #
    # @example Add coercion to an existing attribute
    #   cattr :format
    #   cattr_setter :format do |val|
    #     val.to_s.downcase.to_sym
    #   end
    #
    # @param name [Symbol, String] the name of the attribute
    # @yieldparam value [Object] the value passed to the setter
    # @yieldreturn [Object] the coerced value to be assigned
    # @raise [Cattri::AttributeNotDefinedError] if the attribute is not defined or the writer method does not exist
    # @raise [Cattri::AttributeDefinitionError] if method redefinition fails
    # @return [void]
    def class_attribute_setter(name, &block)
      name = name.to_sym
      attribute = __cattri_class_attributes[name]
      puts "<<< #{attribute} = #{name}>"

      if attribute.nil? || !context.method_defined?(:"#{name}=")
        raise Cattri::AttributeNotDefinedError.new(:class, name)
      end

      attribute.instance_variable_set(:@setter, attribute.send(:normalize_setter, block))
      Cattri::AttributeDefiner.define_writer!(attribute, context)
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

    # Defines a single class-level attribute.
    #
    # This is the internal implementation used by {.class_attribute} and its aliases.
    # It constructs a `Cattri::Attribute`, registers it, and defines the necessary
    # class and instance methods.
    #
    # @param name [Symbol] the name of the attribute to define
    # @param options [Hash] additional attribute options (e.g., :default, :readonly)
    # @param block [Proc, nil] an optional setter block for coercion
    #
    # @raise [Cattri::AttributeDefinedError] if the attribute has already been defined
    # @raise [Cattri::AttributeDefinitionError] if method definition fails
    #
    # @return [void]
    def define_class_attribute(name, options, block) # rubocop:disable Metrics/AbcSize
      options[:access] ||= __cattri_visibility
      attribute = Cattri::Attribute.new(name, :class, options, block)

      raise Cattri::AttributeDefinedError.new(:class, name) if class_attribute_defined?(attribute.name)

      begin
        __cattri_class_attributes[name] = attribute

        Cattri::AttributeDefiner.define_callable_accessor(attribute, context)
        Cattri::AttributeDefiner.define_instance_level_reader(attribute, context) if attribute[:instance_reader]
      rescue StandardError => e
        raise Cattri::AttributeDefinitionError.new(self, attribute, e)
      end
    end

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
