# frozen_string_literal: true

module Cattri
  # Base error class for all exceptions raised by Cattri.
  #
  # All Cattri-specific errors inherit from this class, allowing
  # unified rescue of library-level issues.
  #
  # @example
  #   rescue Cattri::Error => e
  #     puts "Something went wrong with Cattri: #{e.message}"
  class Error < StandardError
    SYSTEM_PATHS = %r{/(gems|ruby)/}.freeze

    def initialize(msg = nil, backtrace: caller)
      super(msg)
      set_backtrace(clean_backtrace(backtrace))
    end

    private

    def clean_backtrace(backtrace)
      return [] unless backtrace

      backtrace.grep_v(SYSTEM_PATHS)
    end
  end

  # Base error for all attribute-related failures.
  #
  # Raised for definition conflicts, invalid configuration, or
  # issues during attribute access or mutation.
  #
  # Builds a message dynamically using DEFAULT_MESSAGE. If an attribute
  # is passed, interpolation keys like :name and :level are filled in.
  # If a nested error is passed, its message is appended and backtrace preserved.
  #
  # @example Basic usage
  #   raise Cattri::AttributeError.new
  #
  # @example With attribute interpolation
  #   raise Cattri::AttributeDefinedError.new(attribute: attr)
  #
  # @example Wrapping an existing error
  #   raise Cattri::AttributeDefinitionError.new(attribute: attr, error: e)
  class AttributeError < Cattri::Error
    # The default fallback message used when no message is provided.
    # @internal Used by AttributeError to dynamically build the error message
    DEFAULT_MESSAGE = "Attribute error"

    # @return [Cattri::Attribute, nil] the attribute associated with the error, if provided
    attr_reader :attribute

    # @return [Exception, nil] the original nested error, if provided
    attr_reader :error

    # Initializes a new AttributeError.
    #
    # @param message [String, nil] an optional custom error message
    # @param attribute [Cattri::Attribute, nil] an optional attribute for message interpolation
    # @param error [Exception, nil] an optional nested error whose message and backtrace are preserved
    def initialize(message = nil, attribute: nil, error: nil)
      message ||= self.class.const_get(:DEFAULT_MESSAGE)
      message = (message % attribute.to_h).capitalize if attribute
      backtrace = caller

      if error
        message = "#{message} -- Error: #{error&.message}"
        backtrace = error&.backtrace
      end

      super(message || DEFAULT_MESSAGE, backtrace: backtrace)

      @attribute = attribute
      @error = error
    end
  end

  # Raised when an attribute is defined more than once.
  #
  # This typically indicates a naming collision or duplicate declaration.
  class AttributeDefinedError < Cattri::AttributeError
    DEFAULT_MESSAGE = "%<level>s attribute :%<name>s has already been defined"
  end

  # Raised when an attribute has not been defined but is being accessed or mutated.
  class AttributeNotDefinedError < Cattri::AttributeError
    DEFAULT_MESSAGE = "%<level>s attribute :%<name>s has not been defined"
  end

  # Raised when an attribute value is unexpectedly nil or empty.
  #
  # Used defensively when attempting to operate on an attribute that must be present.
  class EmptyAttributeError < Cattri::AttributeError
    DEFAULT_MESSAGE = "Unable to process empty attributes"
  end

  # Raised when method definition fails (e.g., reader, writer, or custom setter).
  #
  # This wraps and re-raises the original Ruby error that occurred during method definition.
  class AttributeDefinitionError < Cattri::AttributeError
    DEFAULT_MESSAGE = "Failed to define method for %<level>s attribute `:%<name>s`"
  end

  # Raised when an unsupported attribute level is specified.
  #
  # Only `:class` and `:instance` are valid attribute levels.
  class UnsupportedAttributeLevelError < Cattri::AttributeError
    def initialize(level)
      super("Attribute level :#{level} is not supported")
    end
  end

  # Raised when a block is incorrectly passed when defining multiple attributes.
  #
  # Blocks are only allowed when defining a single attribute.
  class AmbiguousBlockError < Cattri::AttributeError
    DEFAULT_MESSAGE = "Cannot define multiple attributes with a block"
  end

  # Raised when a setter override is attempted without providing a block.
  #
  # Blocks are required for custom setter logic via `cattr_setter` or `iattr_setter`.
  class MissingBlockError < Cattri::AttributeError
    DEFAULT_MESSAGE = "A block is required to override the setter for the %<level>s `:%<name>s`"
  end

  # Raised when attempting to redefine or write to a finalized attribute.
  #
  # Finalized attributes cannot have writers assigned or setters redefined.
  class FinalAttributeError < Cattri::AttributeError
    DEFAULT_MESSAGE = "%<level>s attribute :%<name>s is marked as final and cannot be modified"
  end

  # Raised when a writer is attempted on a readonly attribute.
  #
  # Readonly attributes cannot have writers assigned via `iattr_writer`.
  class ReadonlyAttributeError < Cattri::AttributeError
    DEFAULT_MESSAGE = "%<level>s attribute :%<name>s is marked as readonly and cannot be overwritten"
  end

  # Raised when an attribute is accessed in the wrong context.
  #
  # For example, accessing a class attribute from an instance, or vice versa.
  class InvalidAttributeError < Cattri::AttributeError
    DEFAULT_MESSAGE = "Invalid attribute provided"
  end

  # Raised when a class attribute is expected but an instance attribute is provided.
  class InvalidClassAttributeError < Cattri::InvalidAttributeError
    DEFAULT_MESSAGE = "Invalid class attribute provided, received instance attribute `:%<name>s`"
  end

  # Raised when an instance attribute is expected but a class attribute is provided.
  class InvalidInstanceAttributeError < Cattri::InvalidAttributeError
    DEFAULT_MESSAGE = "Invalid instance attribute provided, received class attribute `:%<name>s`"
  end

  # Base error for all context-related issues outside of attribute-level behavior.
  #
  # Raised when method visibility or dynamic method definition fails.
  class ContextError < Cattri::Error; end

  # Raised when a method is already defined on a target module or class.
  #
  # Used to prevent accidental redefinition unless explicitly overridden with `force: true`.
  class MethodDefinedError < Cattri::ContextError; end
end
