# frozen_string_literal: true

require_relative "attribute"
require_relative "attribute_compiler"
require_relative "context"
require_relative "deferred_attributes"
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
    # @param names [Array<Symbol, String>] the names of the attributes to define
    # @param options [Hash] additional attribute configuration
    # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
    # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
    # @option options [Object, Proc, nil] :default a static value or block for lazy default evaluation
    # @option options [Boolean, nil] :final whether the attribute is final
    # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
    # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
    # @option options [Boolean, nil] :readonly whether the attribute should be read-only (no writer generated)
    # @option options [Boolean, nil] :instance_reader whether to allow instances to read class-level attributes
    # @yieldparam value [Object] optional custom setter coercion logic
    # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
    # @return [void]
    def class_attribute(*names, **options, &block)
      raise Cattri::AmbiguousBlockError if names.size > 1 && block_given?

      attribute_registry.define_class_attributes(names, options: options, block: block)
    end

    # Defines a finalized class attribute.
    #
    # Equivalent to calling `class_attribute(name, final: true, ...)`
    #
    # @param name [Symbol, String] the name of the attribute to define
    # @param value [Object, Proc, nil] a static value or block for lazy default evaluation
    # @param options [Hash] additional attribute configuration
    # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
    # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
    # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
    # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
    # @option options [Boolean, nil] :instance_reader whether to allow instances to read class-level attributes
    # @yieldparam value [Object] optional custom setter coercion logic
    # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
    def final_class_attribute(name, value, **options)
      options = options.merge(default: value, readonly: true, final: true)
      class_attribute(name, **options)
    end

    # Defines a read-only class attribute.
    #
    # Equivalent to calling `class_attribute(name, readonly: true, ...)`
    #
    # @param name [Symbol, String] the name of the attribute to define
    # @param value [Object, Proc, nil] a static value or block for lazy default evaluation
    # @param options [Hash] additional attribute configuration
    # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
    # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
    # @option options [Boolean, nil] :final whether the attribute is final
    # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
    # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
    # @option options [Boolean, nil] :instance_reader whether to allow instances to read class-level attributes
    # @yieldparam value [Object] optional custom setter coercion logic
    # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
    # @return [void]
    def readonly_class_attribute(name, value, **options)
      options = options.merge(default: value, readonly: true)
      class_attribute(name, **options)
    end

    # Defines a read-only class attribute.
    #
    # Equivalent to calling `class_attribute(name, readonly: true, ...)`
    #
    # @param names [Array<Symbol | String>] the names of the attributes to define
    # @param options [Hash] additional attribute options
    # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
    # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
    # @option options [Object, Proc, nil] :default a static value or block for lazy default evaluation
    # @option options [Boolean, nil] :final whether the attribute is final
    # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
    # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
    # @option options [Boolean, nil] :instance_reader whether to allow instances to read class-level attributes
    # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
    # @return [void]
    def class_attribute_reader(*names, **options)
      warn "Cattri.class_attribute_reader is deprecated, please use Cattri.readonly_class_attribute instead"

      default = options.delete(:default)
      names.each do |name|
        readonly_class_attribute(name, default, **options)
      end
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
      attribute = attribute_registry.fetch_attribute!(:class, name)

      unless context.method_defined?(attribute, name: "#{name}=")
        raise Cattri::AttributeNotDefinedError.new(:class, name)
      end

      attribute_registry.redefine_attribute_setter!(attribute, block)
    end

    # Defines an alias method for an existing class-level attribute.
    #
    # This does **not** register a new attribute; it simply defines a method
    # (e.g., a predicate-style alias like `foo?`) that delegates to an existing one.
    #
    # The alias method inherits the visibility of the original attribute.
    #
    # @param alias_name [Symbol, String] the new method name (e.g., `:foo?`)
    # @param original [Symbol, String] the name of the existing attribute to delegate to (e.g., `:foo`)
    # @raise [Cattri::AttributeNotDefinedError] if the original attribute is not defined
    # @return [void]
    def class_attribute_alias(alias_name, original)
      attribute = attribute_registry.fetch_attribute!(:class, original)
      context.define_method(attribute, name: alias_name) { public_send(original) }
    end

    # Returns a list of defined class attribute names.
    #
    # @return [Array<Symbol>]
    def class_attributes
      attribute_registry.defined_attributes(:class, with_ancestors: true).keys
    end

    # @!method cattr(*names, **options, &block)
    #   Alias for {.class_attribute}
    #   @see #class_attribute
    alias cattr class_attribute

    # @!method cattr_accessor(*names, **options, &block)
    #   Alias for {.class_attribute}
    #   @see #class_attribute
    alias cattr_accessor class_attribute

    # @!method final_cattr(name, **options)
    #   Alias for {.final_class_attribute}
    #   @see #final_class_attribute
    alias final_cattr final_class_attribute

    # @!method readonly_cattr(name, value, **options)
    #   Alias for {.readonly_class_attribute}
    #   @see #readonly_class_attribute
    alias readonly_cattr readonly_class_attribute

    # @!method cattr_reader(name, value, **options)
    #   Alias for {.readonly_class_attribute}
    #   @see #readonly_class_attribute
    alias cattr_reader readonly_class_attribute

    # @!method cattr_setter(name, **options)
    #   Alias for {.class_attribute_setter}
    #   @see #class_attribute_setter
    alias cattr_setter class_attribute_setter

    # @!method cattr_alias(name, **options)
    #   Alias for {.class_attribute_alias}
    #   @see #class_attribute_alias
    alias cattr_alias class_attribute_alias

    # @!method cattrs
    #   Alias for {.class_attributes}
    #   @return [Array<Symbol>]
    alias cattrs class_attributes
  end
end
