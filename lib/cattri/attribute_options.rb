# frozen_string_literal: true

require_relative "error"

module Cattri
  # @internal
  #
  # AttributeOptions encapsulates normalized metadata for a single Cattri-defined attribute.
  #
  # It validates, transforms, and freezes all input during initialization,
  # ensuring attribute safety and immutability at runtime.
  #
  # @example
  #   options = AttributeOptions.new(:enabled, default: true, expose: :read_write)
  #   options.name         # => :enabled
  #   options.default.call # => true
  #   options.expose       # => :read_write
  class AttributeOptions
    class << self
      # Validates and normalizes the `expose` configuration.
      #
      # @param expose [Symbol, String] one of: :read, :write, :read_write, :none
      # @return [Symbol]
      # @raise [Cattri::AttributeError] if the value is invalid
      def validate_expose!(expose)
        expose = expose.to_sym
        return expose if EXPOSE_OPTIONS.include?(expose) # steep:ignore

        raise Cattri::AttributeError, "Invalid expose option `#{expose.inspect}` for :#{name}"
      end

      # Validates and normalizes method visibility.
      #
      # @param visibility [Symbol, String] one of: :public, :protected, :private
      # @return [Symbol]
      # @raise [Cattri::AttributeError] if the value is invalid
      def validate_visibility!(visibility)
        visibility = visibility.to_sym
        return visibility if VISIBILITIES.include?(visibility) # steep:ignore

        raise Cattri::AttributeError, "Invalid visibility `#{visibility.inspect}` for :#{name}"
      end
    end

    # Valid method visibility levels.
    VISIBILITIES = %i[public protected private].freeze

    # Valid expose options for method generation.
    EXPOSE_OPTIONS = %i[read write read_write none].freeze

    # Valid scope types.
    SCOPES = %i[class instance].freeze
    private_constant :SCOPES

    # Built-in Ruby value types that are safe to reuse as-is (no dup needed).
    SAFE_VALUE_TYPES = [Numeric, Symbol, TrueClass, FalseClass, NilClass].freeze
    private_constant :SAFE_VALUE_TYPES

    attr_reader :name, :ivar, :final, :scope, :predicate,
                :default, :transformer, :expose, :visibility

    # Initializes a frozen attribute configuration.
    #
    # @param name [Symbol, String] the attribute name
    # @param ivar [Symbol, String, nil] optional custom instance variable name
    # @param final [Boolean] marks the attribute as write-once
    # @param scope [Symbol] indicates if the attribute is class-level (:class) or instance-level (:instance)
    # @param predicate [Boolean] whether to define a `?` predicate method
    # @param default [Object, Proc, nil] default value or callable
    # @param transformer [Proc, nil] optional coercion block
    # @param expose [Symbol] access level to define (:read, :write, :read_write, :none)
    # @param visibility [Symbol] method visibility (:public, :protected, :private)
    def initialize(
      name,
      ivar: nil,
      final: false,
      scope: :instance,
      predicate: false,
      default: nil,
      transformer: nil,
      expose: :read_write,
      visibility: :public
    )
      @name = name.to_sym
      @ivar = normalize_ivar(ivar)
      @final = final
      @scope = validate_scope!(scope)
      @predicate = predicate
      @default = normalize_default(default)
      @transformer = normalize_transformer(transformer)
      @expose = self.class.validate_expose!(expose)
      @visibility = self.class.validate_visibility!(visibility)

      freeze
    end

    # Returns a frozen hash representation of this option set.
    #
    # @return [Hash<Symbol, Object>]
    def to_h
      hash = {
        name: @name,
        ivar: @ivar,
        final: @final,
        scope: @scope,
        predicate: @predicate,
        default: @default,
        transformer: @transformer,
        expose: @expose,
        visibility: @visibility
      }
      hash.freeze
      hash
    end

    # Allows hash-style access to the option set.
    #
    # @param key [Symbol, String]
    # @return [Object]
    def [](key)
      to_h[key.to_sym]
    end

    private

    # Normalizes the instance variable name, defaulting to @name.
    #
    # @param ivar [String, Symbol, nil]
    # @return [Symbol]
    def normalize_ivar(ivar)
      ivar ||= name
      :"@#{ivar.to_s.delete_prefix("@")}"
    end

    # Wraps the default in a Proc with immutability protection.
    #
    # - Returns original Proc if given.
    # - Wraps immutable types as-is.
    # - Duplicates mutable values at runtime.
    #
    # @param default [Object, Proc, nil]
    # @return [Proc]
    def normalize_default(default)
      return default if default.is_a?(Proc)
      return -> { default } if default.frozen? || SAFE_VALUE_TYPES.any? { |t| default.is_a?(t) }

      -> { default.dup }
    end

    # Returns a normalized assignment transformer.
    #
    # Falls back to a default transformer that returns:
    # - `kwargs` if `args.empty?`
    # - the single argument if one is passed
    # - `[*args, kwargs]` otherwise
    #
    # @param transformer [Proc, nil]
    # @return [Proc]
    def normalize_transformer(transformer)
      transformer || lambda { |*args, **kwargs|
        return kwargs if args.empty?
        return args.length == 1 ? args[0] : args if kwargs.empty?

        [*args, kwargs]
      }
    end

    # Validates and normalizes the provided scope value.
    #
    # If `scope` is `nil`, it defaults to `:instance`. If it's one of the allowed
    # values (`:class`, `:instance`), it is returned as-is. Otherwise, an error is raised.
    #
    # @param scope [Symbol, nil] the requested attribute scope
    # @return [Symbol] the validated scope (`:class` or `:instance`)
    # @raise [Cattri::AttributeError] if the scope is invalid
    def validate_scope!(scope)
      return :instance if scope.nil?
      return scope if SCOPES.include?(scope)

      raise Cattri::AttributeError, "Invalid scope `#{scope.inspect}` for :#{name}. Must be :class or :instance"
    end
  end
end
