# frozen_string_literal: true

require_relative "attribute_compiler"

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
      # Defines one or more instance-level attributes with optional default, coercion, and access control.
      #
      # This method supports defining multiple attributes at once, provided they share the same options.
      # If a block is given, only one attribute may be defined to avoid ambiguity.
      #
      # @example Define multiple attributes with shared defaults
      #   instance_attribute :foo, :bar, default: []
      #
      # @example Define a single attribute with coercion
      #   instance_attribute :level do |val|
      #     Integer(val)
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
      # @option options [Boolean, nil] :reader whether to generate a reader method (only applies to instance attributes)
      # @option options [Boolean, nil] :writer whether to generate a writer method (only applies to instance attributes)
      # @yieldparam value [Object] optional custom setter coercion logic
      # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
      # @return [void]
      def instance_attribute(*names, **options, &block)
        raise Cattri::AmbiguousBlockError if names.size > 1 && block_given?

        attribute_registry.define_instance_attributes(names, options: options, block: block)
      end

      # Defines a write-only instance-level attribute.
      #
      # Equivalent to `instance_attribute(..., reader: false)`. The predicate: option is not allowed
      # when defining writer methods.
      #
      # @param name [Array<Symbol, String>] the names of the attributes to define
      # @param value [Object, Proc, nil] a static value or block for lazy default evaluation
      # @param options [Hash] additional attribute configuration
      # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
      # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
      # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
      # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
      # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
      # @return [void]
      def final_instance_attribute(name, value, **options)
        options = options.merge(default: value, final: true, reader: true, writer: false)
        instance_attribute(name, **options)
      end

      # Defines a read-only instance-level attribute.
      #
      # Equivalent to `instance_attribute(..., writer: false)`
      #
      # @param name [Symbol, String] the name of the attribute to define
      # @param value [Object, Proc, nil] a static value or block for lazy default evaluation
      # @param options [Hash] additional attribute configuration
      # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
      # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
      # @option options [Boolean, nil] :final whether the attribute is final
      # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
      # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
      # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
      # @return [void]
      def readonly_instance_attribute(name, value, **options)
        options = options.merge(default: value, reader: true, writer: false)
        instance_attribute(name, **options)
      end

      # @param names [Array<Symbol, String>] the names of the attributes to define
      # @param options [Hash] additional attribute configuration
      # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
      # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
      # @option options [Object, Proc, nil] :default a static value or block for lazy default evaluation
      # @option options [Boolean, nil] :final whether the attribute is final
      # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
      # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
      # @yieldparam value [Object] optional custom setter coercion logic
      # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
      # @return [void]
      def instance_attribute_reader(*names, **options, &_block)
        warn "Cattri.instance_attribute_reader is deprecated, please use Cattri.readonly_instance_attribute instead"

        default = options.delete(:default)
        names.each do |name|
          readonly_instance_attribute(name, default, **options)
        end
      end

      # Defines a write-only instance-level attribute.
      #
      # Equivalent to `instance_attribute(..., reader: false)`. The predicate: option is not allowed
      # when defining writer methods.
      #
      # @param names [Array<Symbol, String>] the names of the attributes to define
      # @param options [Hash] additional attribute configuration
      # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
      # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
      # @option options [Object, Proc, nil] :default a static value or block for lazy default evaluation
      # @option options [Boolean, nil] :final whether the attribute is final
      # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
      # @yieldparam value [Object] optional custom setter coercion logic
      # @raise [Cattri::AttributeError] or its subclasses if defining the attribute fails
      # @return [void]
      def instance_attribute_writer(*names, **options, &block)
        names.each do |name|
          if (attribute = attribute_registry.fetch_attribute(:instance, name))
            attribute.guard_writable!
          end
        end

        options = options.merge(reader: false, writer: true, predicate: false)
        instance_attribute(*names, **options, &block)
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
        attribute = attribute_registry.fetch_attribute!(:instance, name)
        attribute_registry.redefine_attribute_setter!(attribute, block)
      end

      # Defines an alias method for an existing instance-level attribute.
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
      def instance_attribute_alias(alias_name, original)
        attribute = attribute_registry.fetch_attribute!(:instance, original)
        context.define_method(attribute, name: alias_name) { public_send(original) }
      end

      # Returns a list of defined instance-level attribute names.
      #
      # @return [Array<Symbol>]
      def instance_attributes
        attribute_registry.defined_attributes(:instance, with_ancestors: true).keys
      end

      # @!method iattr(*names, **options, &block)
      #   Alias for {#instance_attribute}
      #   @see #instance_attribute
      alias iattr instance_attribute

      # @!method iattr_accessor(*names, **options, &block)
      #   Alias for {#instance_attribute}
      #   @see #instance_attribute
      alias iattr_accessor instance_attribute

      # @!method final_iattr(name, value, **options)
      #   Alias for {#final_instance_attribute}
      #   @see #final_instance_attribute
      alias final_iattr final_instance_attribute

      # @!method readonly_iattr(name, value, **options)
      #   Alias for {#readonly_instance_attribute}
      #   @see #readonly_instance_attribute
      alias readonly_iattr readonly_instance_attribute

      # @!method iattr_reader(name, value, **options)
      #   Alias for {#readonly_instance_attribute}
      #   @see #readonly_instance_attribute
      alias iattr_reader readonly_instance_attribute

      # @!method iattr_writer(*names, **options, &block)
      #   Alias for {#instance_attribute_writer}
      #   @see #instance_attribute_writer
      alias iattr_writer instance_attribute_writer

      # @!method iattr_setter(name, &block)
      #   Alias for {#instance_attribute_setter}
      #   @see #instance_attribute_setter
      alias iattr_setter instance_attribute_setter

      # @!method iattr_alias(name, &block)
      #   Alias for {#instance_attribute_alias}
      #   @see #instance_attribute_alias
      alias iattr_alias instance_attribute_alias

      # @!method iattrs
      #   Alias for {#instance_attributes}
      #   @see #instance_attributes
      alias iattrs instance_attributes
    end
  end
end
