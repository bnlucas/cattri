# frozen_string_literal: true

require_relative "attribute_options"

module Cattri
  # @internal
  #
  # Attribute acts as a thin wrapper around AttributeOptions,
  # exposing core attribute metadata and behavior in a safe, immutable way.
  #
  # Each Attribute instance represents a single logical property,
  # and delegates its behavior (default, visibility, coercion, etc.) to its associated AttributeOptions.
  #
  # @example
  #   attribute = Attribute.new(:enabled, default: true, expose: :read_write)
  #   attribute.name          # => :enabled
  #   attribute.default.call  # => true
  #   attribute.expose        # => :read_write
  class Attribute
    # @return [Module] the class or module this attribute was defined in
    attr_reader :defined_in

    # Initializes a new attribute definition.
    #
    # @param name [Symbol, String] the attribute name
    # @param defined_in [Module] the class or module where this attribute is defined
    # @param options [Hash] configuration options
    # @option options [Boolean] :scope whether the attribute is class-level (internally mapped to :class_attribute)
    # @param transformer [Proc] optional block used to coerce/validate assigned values
    def initialize(name, defined_in:, **options, &transformer)
      @options = Cattri::AttributeOptions.new(name, transformer: transformer, **options)
      @defined_in = defined_in
    end

    # Serializes this attribute and its configuration to a frozen hash.
    #
    # @return [Hash<Symbol, Object>]
    def to_h
      {
        name: @options.name,
        ivar: @options.ivar,
        defined_in: @defined_in,
        final: @options.final,
        scope: @options.scope,
        predicate: @options.predicate,
        default: @options.default,
        transformer: @options.transformer,
        expose: @options.expose,
        visibility: @options.visibility
      }
    end

    # @!attribute [r] name
    #   @return [Symbol] the canonical name of the attribute

    # @!attribute [r] ivar
    #   @return [Symbol] the backing instance variable (e.g., :@enabled)

    # @!attribute [r] default
    #   @return [Proc] a callable lambda for the attribute’s default value

    # @!attribute [r] transformer
    #   @return [Proc] a callable transformer used to process assigned values

    # @!attribute [r] expose
    #   @return [Symbol] method exposure type (:read, :write, :read_write, or :none)

    # @!attribute [r] visibility
    #   @return [Symbol] method visibility (:public, :protected, :private)

    %i[
      name
      ivar
      default
      transformer
      expose
      visibility
    ].each do |option|
      define_method(option) { @options.public_send(option) }
    end

    # @return [Boolean] whether the reader should remain internal
    def internal_reader?
      %i[write none].include?(@options.expose)
    end

    # @return [Boolean] whether the writer should remain internal
    def internal_writer?
      %i[read none].include?(@options.expose)
    end

    # @return [Boolean] whether the attribute allows reading
    def readable?
      %i[read read_write].include?(@options.expose)
    end

    # @return [Boolean] whether the attribute allows writing
    def writable?
      return false if @options.expose == :none

      !readonly?
    end

    # @return [Boolean] whether the attribute is marked readonly
    def readonly?
      return false if @options.expose == :none

      @options.expose == :read || final?
    end

    # @return [Boolean] whether the attribute is marked final (write-once)
    def final?
      @options.final
    end

    # @return [Boolean] whether the attribute is class-level
    def class_attribute?
      @options.scope == :class
    end

    # @return [Boolean] whether the attribute defines a predicate method (`:name?`)
    def with_predicate?
      @options.predicate
    end

    # Returns the methods that will be defined for this attribute.
    #
    # Includes the base accessor, optional writer, and optional predicate.
    #
    # @return [Array<Symbol>] a list of method names
    def allowed_methods
      [name, (:"#{name}=" if writable?), (:"#{name}?" if with_predicate?)].compact.freeze
    end

    # Validates whether this attribute is assignable in the current context.
    #
    # @raise [Cattri::AttributeError] if assignment is disallowed
    def validate_assignment!
      if final?
        raise Cattri::AttributeError, "Cannot assign to final attribute `:#{name}`"
      elsif readonly?
        raise Cattri::AttributeError, "Cannot assign to readonly attribute `:#{name}`"
      end
    end

    # Resolves the default value for this attribute.
    #
    # @return [Object] the evaluated default
    # @raise [Cattri::AttributeError] if default evaluation fails
    def evaluate_default
      @options.default.call
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to evaluate the default value for `:#{@options.name}`. Error: #{e.message}"
    end

    # Processes and transforms an incoming assignment for this attribute.
    #
    # @param args [Array] positional arguments to pass to the transformer
    # @param kwargs [Hash] keyword arguments to pass to the transformer
    # @return [Object] the transformed value
    # @raise [Cattri::AttributeError] if transformation fails
    def process_assignment(*args, **kwargs)
      @options.transformer.call(*args, **kwargs)
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to evaluate the setter for `:#{@options.name}`. Error: #{e.message}"
    end
  end
end
