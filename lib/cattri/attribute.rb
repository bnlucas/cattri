# frozen_string_literal: true

require_relative "error"

module Cattri
  # Represents a single attribute definition in Cattri.
  #
  # This class encapsulates metadata and behavior for a declared attribute,
  # including name, visibility, default value, and setter coercion logic.
  #
  # It is used internally by the DSL to configure how accessors are defined,
  # memoized, and resolved at runtime.
  class Attribute
    # Supported attribute scopes within Cattri.
    ATTRIBUTE_TYPES = %i[class instance].freeze

    # Supported Ruby method visibility levels.
    ACCESS_LEVELS = %i[public protected private].freeze

    # Ruby value types considered safe to reuse as-is (no `#dup` needed).
    SAFE_VALUE_TYPES = [Numeric, Symbol, TrueClass, FalseClass, NilClass].freeze

    # Default options for class-level attributes.
    DEFAULT_CLASS_ATTRIBUTE_OPTIONS = {
      readonly: false,
      instance_reader: true
    }.freeze

    # Default options for instance-level attributes.
    DEFAULT_INSTANCE_ATTRIBUTE_OPTIONS = {
      reader: true,
      writer: true
    }.freeze

    # @return [Symbol] the attribute name
    attr_reader :name

    # @return [Symbol] the attribute type (:class or :instance)
    attr_reader :type

    # @return [Symbol] the associated instance variable (e.g., :@items)
    attr_reader :ivar

    # @return [Symbol] the access level (:public, :protected, :private)
    attr_reader :access

    # @return [Proc] the normalized default value block
    attr_reader :default

    # @return [Proc] the setter function used to assign values
    attr_reader :setter

    # Initializes a new attribute definition.
    #
    # @param name [String, Symbol] the name of the attribute
    # @param type [Symbol] either :class or :instance
    # @param options [Hash] additional attribute configuration
    # @param block [Proc, nil] optional block for setter coercion
    #
    # @raise [Cattri::UnsupportedTypeError] if an invalid type is provided
    def initialize(name, type, options, block)
      @type = type.to_sym
      raise Cattri::UnsupportedTypeError, type unless ATTRIBUTE_TYPES.include?(@type)

      @name = name.to_sym
      @ivar = normalize_ivar(options[:ivar])
      @access = options[:access] || :public
      @default = normalize_default(options[:default])
      @setter = normalize_setter(block)
      @options = typed_options(options)
    end

    # Hash-like access to option values or metadata.
    #
    # @param key [Symbol, String]
    # @return [Object]
    def [](key)
      to_hash[key.to_sym]
    end

    # Serializes this attribute to a hash, including core properties and type-specific flags.
    #
    # @return [Hash]
    def to_hash
      @to_hash ||= {
        name: @name,
        ivar: @ivar,
        type: @type,
        access: @access,
        default: @default,
        setter: @setter
      }.merge(@options)
    end

    alias to_h to_hash

    # @return [Boolean] true if the attribute is class-scoped
    def class_level?
      type == :class
    end

    # @return [Boolean] true if the attribute is instance-scoped
    def instance_level?
      type == :instance
    end

    # @return [Boolean] whether the attribute is public
    def public?
      access == :public
    end

    # @return [Boolean] whether the attribute is protected
    def protected?
      access == :protected
    end

    # @return [Boolean] whether the attribute is private
    def private?
      access == :private
    end

    # Invokes the default value logic for the attribute.
    #
    # @return [Object] the default value for the attribute
    # @raise [Cattri::AttributeError] if the default value logic raises an error
    def invoke_default
      default.call
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to evaluate the default value for :#{name}. Error: #{e.message}"
    end

    # Invokes the setter function with error handling
    #
    # @param args [Array] the positional arguments
    # @param kwargs [Hash] the keyword arguments
    # @raise [Cattri::AttributeError] if setter raises an error
    # @return [Object] the value returned by the setter
    def invoke_setter(*args, **kwargs)
      setter.call(*args, **kwargs)
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to evaluate the setter for :#{name}. Error: #{e.message}"
    end

    private

    # Applies class- or instance-level defaults and filters valid option keys.
    #
    # @param options [Hash]
    # @return [Hash]
    def typed_options(options)
      defaults = type == :class ? DEFAULT_CLASS_ATTRIBUTE_OPTIONS : DEFAULT_INSTANCE_ATTRIBUTE_OPTIONS
      defaults.merge(options.slice(*defaults.keys))
    end

    # Normalizes the instance variable name for the attribute.
    #
    # @param ivar [String, Symbol, nil]
    # @return [Symbol]
    def normalize_ivar(ivar)
      ivar ||= name
      :"@#{ivar.to_s.delete_prefix("@")}"
    end

    # Returns the setter proc. If no block is provided, uses default logic:
    # - Returns kwargs if given
    # - Returns the single positional argument if one
    # - Returns all args as an array otherwise
    #
    # @param block [Proc, nil]
    # @return [Proc]
    def normalize_setter(block)
      block || lambda { |*args, **kwargs|
        return kwargs unless kwargs.empty?
        return args.first if args.length == 1

        args
      }
    end

    # Wraps the default value in a memoized lambda.
    #
    # If value is already callable, returns it.
    # If immutable, wraps it in a lambda.
    # If mutable, wraps it in a lambda that calls `#dup`.
    #
    # @param default [Object, Proc, nil]
    # @return [Proc]
    def normalize_default(default)
      return default if default.respond_to?(:call)
      return -> { default } if default.frozen? || SAFE_VALUE_TYPES.any? { |type| default.is_a?(type) }

      lambda {
        begin
          default.dup
        rescue StandardError => e
          raise Cattri::AttributeError,
                "Failed to duplicate default value for :#{name}. Error: #{e.message}"
        end
      }
    end
  end
end
