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
  class Error < StandardError; end

  # Base error for all attribute-related failures.
  #
  # Raised for definition conflicts, invalid configuration, or
  # issues during attribute access or mutation.
  #
  # @example
  #   rescue Cattri::AttributeError => e
  #     puts "Attribute error: #{e.message}"
  class AttributeError < Cattri::Error; end

  # Base error for all context-related issues.
  #
  # Raised when an error occurs while defining methods or
  # resolving method visibility in the given context.
  #
  # @example
  #   rescue Cattri::ContextError => e
  #     puts "Context error: #{e.message}"
  class ContextError < Cattri::Error; end

  # Raised when an attribute is defined more than once.
  #
  # This typically indicates a naming collision or duplicate declaration.
  #
  # @example
  #   raise Cattri::AttributeDefinedError.new(:instance, :name)
  class AttributeDefinedError < Cattri::AttributeError
    # @param level [Symbol] :class or :instance
    # @param name [Symbol] attribute name
    def initialize(level, name)
      super("#{level.capitalize} attribute :#{name} has already been defined")
    end
  end

  # Raised when an attribute has not been defined but is being accessed or mutated.
  #
  # This applies to both class-level and instance-level attributes.
  #
  # @example
  #   raise Cattri::AttributeNotDefinedError.new(:class, :foo)
  class AttributeNotDefinedError < Cattri::AttributeError
    # @param level [Symbol] :class or :instance
    # @param name [Symbol] attribute name
    def initialize(level = nil, name = nil)
      super("#{level.capitalize} attribute :#{name} has not been defined")
    end
  end

  # Raised when an attribute value is unexpectedly nil or empty.
  #
  # Used defensively when attempting to operate on an attribute
  # that must be present but is missing or uninitialized.
  class EmptyAttributeError < Cattri::Error
    def initialize
      super("Unable to process empty attributes")
    end
  end

  # Raised when method definition fails (e.g., reader, writer, or custom setter).
  #
  # This wraps and re-raises the original Ruby error that occurred.
  #
  # @example
  #   raise Cattri::AttributeDefinitionError.new(self, attribute, error)
  class AttributeDefinitionError < Cattri::AttributeError
    # @param target [Module] the receiving class or module
    # @param attribute [Cattri::Attribute] the attribute being defined
    # @param error [Exception] the original raised error
    def initialize(target, attribute, error)
      super("Failed to define method :#{attribute.name} on #{target}. Error: #{error.message}")
      set_backtrace(error.backtrace)
    end
  end

  # Raised when an unsupported attribute level is specified.
  #
  # Only `:class` and `:instance` are valid levels.
  #
  # @example
  #   raise Cattri::UnsupportedLevelError.new(:global)
  class UnsupportedLevelError < Cattri::AttributeError
    # @param level [Symbol] the invalid level
    def initialize(level)
      super("Attribute level :#{level} is not supported")
    end
  end

  # Raised when a block is incorrectly passed when defining multiple attributes.
  #
  # Blocks are only allowed when defining a single attribute.
  #
  # @example
  #   cattr :foo, :bar do ... end #=> raises AmbiguousBlockError
  class AmbiguousBlockError < Cattri::AttributeError
    def initialize
      super("Cannot define multiple attributes with a block")
    end
  end

  # Raised when a setter override is attempted without providing a block.
  #
  # Blocks are required for custom setter logic via `cattr_setter` or `iattr_setter`.
  #
  # @example
  #   iattr_setter :value #=> raises MissingBlockError
  class MissingBlockError < Cattri::AttributeError
    # @param level [Symbol] :class or :instance
    # @param name [Symbol] the attribute name
    def initialize(level, name)
      super("A block is required to override the setter for `:#{name}` (#{level} attribute)")
    end
  end

  # Raised when attempting to redefine or write to a finalized attribute.
  #
  # Finalized attributes cannot have writers assigned via `iattr_writer` and cannot have setters
  # updated via `cattr_setter` or `iattr_setter`.
  #
  # @example
  #   final_iattr :attr
  #   iattr_setter :attr do |value| #=> raises FinalizedAttributeError.
  #     value.to_s
  #   end
  class FinalizedAttributeError < Cattri::AttributeError
    def initialize(level, name)
      super("#{level.capitalize} attribute :#{name} is marked as final and cannot be modified")
    end
  end

  # Raised when a writer definition is attempted on a readonly attribute.
  #
  # Readonly attributes cannot have writers assigned via `iattr_writer`.
  #
  # @example
  #   iattr :token, readonly: true
  #   iattr_writer :token { |v| ... } #=> raises ReadonlyAttributeError
  class ReadonlyAttributeError < Cattri::AttributeError
    # @param name [Symbol] attribute name
    def initialize(level, name)
      super("#{level.capitalize} attribute :#{name} is marked as readonly and cannot be overwritten")
    end
  end

  # Raised when an attribute is accessed in the wrong context.
  #
  # For example, accessing a class attribute using an instance accessor.
  #
  # @example
  #   raise Cattri::InvalidAttributeContextError.new(:class, attribute)
  class InvalidAttributeContextError < Cattri::AttributeError
    # @param level [Symbol] expected level (:class or :instance)
    # @param attribute [Cattri::Attribute]
    def initialize(level, attribute)
      super(
        "Invalid attribute level for :#{attribute.name}. " \
        "Expected :#{level}, got :#{attribute.level}"
      )
    end
  end

  # Raised when a method is already defined on the target.
  #
  # Used to prevent accidental method redefinition unless explicitly overridden with `force: true`.
  #
  # @example
  #   raise Cattri::MethodDefinedError.new(:name, MyClass)
  class MethodDefinedError < Cattri::ContextError
    # @param name [Symbol] the method name
    # @param target [Module] the target class or module
    def initialize(name, target)
      super("Method `:#{name}` already exists on #{target}. Use `force: true` to override")
    end
  end
end
