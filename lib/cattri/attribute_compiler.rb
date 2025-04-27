# frozen_string_literal: true

module Cattri
  # Compiles Cattri::Attribute instances into accessor methods on a given target
  # class using Cattri's Context.
  #
  # This class provides a centralized set of methods to generate attribute-related
  # behavior (readers, writers, predicates) for both class-level and instance-level
  # attributes, using the provided `Cattri::Context`.
  #
  # It supports default values, coercion, memoization, and visibility enforcement.
  # All method definitions are routed through the `Context` abstraction to ensure
  # consistent scoping and override safety.
  class AttributeCompiler
    class << self
      # Defines a class-level accessor method.
      #
      # Returns a memoized default if called with no arguments, otherwise sets the value.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def class_accessor(attribute, context)
        validate_level!(attribute, :class)

        define_accessor(attribute, context)
        class_writer(attribute, context) if attribute.writable?
        class_predicate(attribute, context) if attribute[:predicate]

        delegate_to_class_reader(attribute, context) if attribute[:instance_reader]
      end

      # Defines a class-level writer method.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def class_writer(attribute, context)
        validate_level!(attribute, :class)

        define_writer(attribute, context)
      end

      # Defines a class-level predicate method (`:name?`) that checks the truthiness of the attribute.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def class_predicate(attribute, context)
        validate_level!(attribute, :class)

        define_predicate(attribute, context)
        delegate_to_class_predicate(attribute, context) if attribute[:instance_reader]
      end

      # Defines an instance-level reader that delegates to the class-level reader.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def delegate_to_class_reader(attribute, context)
        validate_level!(attribute, :class)

        delegate_to_class(attribute.name, context) do
          self.class.__send__(attribute.name)
        end
      end

      # Defines an instance-level predicate that delegates to the class-level predicate.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def delegate_to_class_predicate(attribute, context)
        validate_level!(attribute, :class)

        delegate_to_class(:"#{attribute.name}?", context) do
          !!self.class.__send__(attribute.name) # rubocop:disable Style/DoubleNegation
        end
      end

      # Defines both reader and writer instance-level methods, if allowed by the attribute.
      #
      # A predicate is also defined if `predicate: true` was used on the attribute.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def instance_accessor(attribute, context)
        validate_level!(attribute, :instance)

        instance_reader(attribute, context) if attribute.readable?
        instance_writer(attribute, context) if attribute.writable?
        instance_predicate(attribute, context) if attribute[:predicate]
      end

      # Defines an instance-level reader method with default memoization.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def instance_reader(attribute, context)
        validate_level!(attribute, :instance)

        context.define_method(attribute) do
          AttributeCompiler.send(:memoize_default_value, self, attribute)
        end
      end

      # Defines an instance-level writer method.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def instance_writer(attribute, context)
        validate_level!(attribute, :instance)

        define_writer(attribute, context)
      end

      # Defines an instance-level predicate method (`:name?`) for the attribute.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def instance_predicate(attribute, context)
        validate_level!(attribute, :instance)

        define_predicate(attribute, context)
      end

      private

      # Defines a callable accessor for the attribute.
      #
      # @example as a reader
      #   puts MyClass.attr #=> attr's ivar value
      #
      # @example as a writer
      #   puts MyClass.attr "value" #=> writes to the ivar
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      def define_accessor(attribute, context)
        context.define_method(attribute) do |*args, **kwargs|
          readonly_call = args.empty? && kwargs.empty?
          return AttributeCompiler.send(:memoize_default_value, self, attribute) if readonly_call

          attribute.guard_writable!

          value = attribute.invoke_setter(*args, **kwargs)
          instance_variable_set(attribute.ivar, value)
        end
      end

      # Defines a writer method (`:name=`), optionally forcing redefinition.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_writer(attribute, context)
        block = proc do |value|
          coerced_value = attribute.invoke_setter(value)
          instance_variable_set(attribute.ivar, coerced_value)
        end

        context.define_method(attribute, name: :"#{attribute.name}=", &block)
      end

      # Defines a `:name?` predicate method that checks the truthiness of the attribute.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_predicate(attribute, context)
        context.define_method(attribute, name: :"#{attribute.name}?") do
          !!send(attribute.name) # rubocop:disable Style/DoubleNegation
        end
      end

      # Defines a method on the target that delegates to a class-level method.
      #
      # @param name [Symbol, String]
      # @param context [Cattri::Context]
      # @yieldreturn [Object]
      # @return [void]
      def delegate_to_class(name, context, &block)
        context.target.define_method(name.to_sym, &block)
      end

      # Memoizes and returns the default value for the attribute if not already initialized.
      #
      # @param receiver [Object]
      # @param attribute [Cattri::Attribute]
      # @return [Object]
      # @raise [Cattri::AttributeError] if default value raises an exception
      def memoize_default_value(receiver, attribute)
        if attribute.final?
          if receiver.instance_variable_defined?(attribute.ivar)
            return receiver.instance_variable_get(attribute.ivar)
          else
            raise Cattri::FinalAttributeNilError,
                  "Final attribute :#{attribute.name} must be explicitly assigned before reading."
          end
        end

        receiver.instance_variable_set(attribute.ivar, attribute.invoke_default)
      end

      def validate_level!(attribute, level)
        return if attribute.level == level

        if level == :class && attribute.level == :instance
          raise Cattri::InvalidClassAttributeError.new(attribute: attribute)
        elsif level == :instance && attribute.level == :class
          raise Cattri::InvalidInstanceAttributeError.new(attribute: attribute)
        else
          raise Cattri::InvalidAttributeError
        end
      end
    end
  end
end
