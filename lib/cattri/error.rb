# frozen_string_literal: true

module Cattri
  # Base error class for all exceptions raised by Cattri.
  #
  # All Cattri-specific errors inherit from this class.
  #
  # @example
  #   rescue Cattri::Error => e
  #     puts "Something went wrong with Cattri: #{e.message}"
  class Error < StandardError; end

  # Parent class for all attribute-related errors in Cattri.
  #
  # This includes definition conflicts, setter failures, or configuration issues.
  #
  # @example
  #   rescue Cattri::AttributeError => e
  #     puts "Attribute error: #{e.message}"
  class AttributeError < Cattri::Error; end

  # Raised when a class or instance attribute is defined more than once.
  #
  # This helps detect naming collisions during DSL usage.
  #
  # @example
  #   raise Cattri::AttributeDefinedError.new(attribute)
  #
  # @example
  #   rescue Cattri::AttributeDefinedError => e
  #     puts e.message
  class AttributeDefinedError < Cattri::AttributeError
    # @param attribute [Cattri::Attribute] the conflicting attribute
    def initialize(attribute)
      super("#{attribute.type.capitalize} attribute :#{attribute.name} has already been defined")
    end
  end

  # Raised when a method definition (reader, writer, or callable) fails.
  #
  # This wraps the original error that occurred during `define_method` or visibility handling.
  #
  # @example
  #   raise Cattri::AttributeDefinitionError.new(target, attribute, error)
  #
  # @example
  #   rescue Cattri::AttributeDefinitionError => e
  #     puts e.message
  class AttributeDefinitionError < Cattri::AttributeError
    # @param target [Module] the class or module receiving the method
    # @param attribute [Cattri::Attribute] the attribute being defined
    # @param error [StandardError] the original raised exception
    def initialize(target, attribute, error)
      super("Failed to define method :#{attribute.name} on #{target}. Error: #{error.message}")
      set_backtrace(error.backtrace)
    end
  end

  # Raised when an unsupported attribute type is passed to Cattri.
  #
  # Valid types are typically `:class` and `:instance`. Any other value is invalid.
  #
  # @example
  #   raise Cattri::UnsupportedTypeError.new(:foo)
  #   # => Attribute type :foo is not supported
  class UnsupportedTypeError < Cattri::AttributeError
    # @param type [Symbol] the invalid type that triggered the error
    def initialize(type)
      super("Attribute type :#{type} is not supported")
    end
  end

  # Raised when a block is provided when defining a group of attributes `cattr :attr_a, :attr_b do ... end`
  #
  # @example
  #   raise Cattri::AmbiguousBlockError
  #   # => Cannot define multiple attributes with a block
  class AmbiguousBlockError < Cattri::AttributeError
    def initialize
      super("Cannot define multiple attributes with a block")
    end
  end
end
