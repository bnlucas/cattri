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
    ATTRIBUTE_LEVELS = %i[class instance].freeze

    # Ruby value types considered safe to reuse as-is (no `#dup` needed).
    SAFE_VALUE_TYPES = [Numeric, Symbol, TrueClass, FalseClass, NilClass].freeze

    # Default options for all attributes.
    DEFAULT_ATTRIBUTE_OPTIONS = {
      final: false,
      readonly: false,
      predicate: false,
      force: false
    }.freeze

    # Default options for class-level attributes.
    DEFAULT_CLASS_ATTRIBUTE_OPTIONS = {
      instance_reader: true
    }.merge(DEFAULT_ATTRIBUTE_OPTIONS).freeze

    # Default options for instance-level attributes.
    DEFAULT_INSTANCE_ATTRIBUTE_OPTIONS = {
      reader: true,
      writer: true
    }.merge(DEFAULT_ATTRIBUTE_OPTIONS).freeze

    # @return [Symbol] the attribute name
    attr_reader :name

    # @return [Symbol] the attribute level (:class or :instance)
    attr_reader :level

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
    # @param level [Symbol] either :class or :instance
    # @param options [Hash] additional attribute configuration
    # @option options [String, Symbol, nil] :access the attribute's access visibility, defaults to `:public`
    # @option options [String, Symbol, nil] :ivar the backing instance variable name (defaults to `:@name`)
    # @option options [Object, Proc, nil] :default a static value or block for lazy default evaluation
    # @option options [Boolean, nil] :final whether the attribute is final
    # @option options [Boolean, nil] :predicate whether to generate a predicate method (`attr?`)
    # @option options [Boolean, nil] :force whether to forcibly overwrite existing methods if already defined
    # @option options [Boolean, nil] :readonly whether the attribute should be read-only (no writer generated)
    # @option options [Boolean, nil] :instance_reader whether to allow instances to read class-level attributes
    # @option options [Boolean, nil] :reader whether to generate a reader method (only applies to instance attributes)
    # @option options [Boolean, nil] :writer whether to generate a writer method (only applies to instance attributes)
    # @param defined_in [Cattri::Context, nil] optional context instance where the attribute was originally defined
    # @param block [Proc, nil] optional block for setter coercion or transformation
    # @raise [Cattri::UnsupportedLevelError] if an invalid level is provided
    def initialize(name, level, defined_in: nil, **options, &block)
      @level = level.to_sym
      raise Cattri::UnsupportedLevelError, level unless ATTRIBUTE_LEVELS.include?(@level)

      @name = name.to_sym
      @ivar = normalize_ivar(options[:ivar])
      @defined_in = defined_in
      @access = options[:access] || :public
      @default = normalize_default(options[:default])
      @setter = normalize_setter(block)
      @options = level_options(options)
    end

    # Hash-like access to option values or metadata.
    #
    # @param key [Symbol, String]
    # @return [Object]
    def [](key)
      to_hash[key.to_sym]
    end

    # Serializes this attribute to a hash, including core properties and level-specific flags.
    #
    # @return [Hash]
    def to_hash
      @to_hash ||= {
        name: @name,
        ivar: @ivar,
        level: @level,
        defined_in: @defined_in,
        access: @access,
        default: @default,
        setter: @setter
      }.merge(@options)
    end

    alias to_h to_hash

    # @return [Boolean] true if the attribute is class-scoped
    def class_level?
      level == :class
    end

    # @return [Boolean] true if the attribute is instance-scoped
    def instance_level?
      level == :instance
    end

    # @return [Boolean] whether the attribute is marked final
    def final?
      !!to_h[:final]
    end

    # @return [Boolean] whether the attribute is marked readonly
    def readonly?
      !!to_h[:readonly]
    end

    # @return [Boolean] whether the attribute is readable
    def readable?
      class_level? || !!to_h[:reader]
    end

    # @return [Boolean] whether the attribute is writable
    def writable?
      !final? && !readonly?
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
      raise Cattri::FinalizedAttributeError.new(level, name) if final?

      setter.call(*args, **kwargs)
    rescue Cattri::FinalizedAttributeError
      raise
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to evaluate the setter for :#{name}. Error: #{e.message}"
    end

    # Guard to ensure the attribute is writable.
    #
    # @raise [Cattri::FinalizedAttributeError] for finalized attributes
    # @raise [Cattri::ReadonlyAttributeError] for readonly attributes
    def guard_writable!
      if final?
        raise Cattri::FinalizedAttributeError.new(level, name)
      elsif readonly?
        raise Cattri::ReadonlyAttributeError.new(level, name)
      end
    end

    private

    # Applies class- or instance-level defaults and filters valid option keys.
    #
    # @param options [Hash]
    # @return [Hash]
    def level_options(options)
      defaults = level == :class ? DEFAULT_CLASS_ATTRIBUTE_OPTIONS : DEFAULT_INSTANCE_ATTRIBUTE_OPTIONS
      defaults.merge(options.slice(*defaults.keys)).tap do |opts|
        if level == :instance
          opts[:writer] = false if opts[:final]
          opts[:readonly] = opts[:reader] && !opts[:writer]
        end
      end
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
