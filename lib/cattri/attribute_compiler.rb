# frozen_string_literal: true

module Cattri
  # @internal
  #
  # Responsible for defining methods on the target class/module
  # based on the metadata in a {Cattri::Attribute}.
  #
  # This includes:
  # - callable accessors (acting as both reader and writer)
  # - predicate methods
  # - explicit writers (`:name=` methods)
  #
  # Handles both instance and class-level attributes, including
  # memoization and validation of default values for final attributes.
  class AttributeCompiler
    class << self
      # Defines accessor methods for the given attribute in the provided context.
      #
      # For `final` + `scope: :class` attributes, the default is eagerly assigned.
      # Then, if permitted by `expose`, the reader, writer, and/or predicate methods are defined.
      #
      # @param attribute [Cattri::Attribute] the attribute to define
      # @param context [Cattri::Context] the target context for method definition
      # @return [void]
      def define_accessor(attribute, context)
        if attribute.class_attribute? && attribute.final?
          value = attribute.evaluate_default
          context.storage_receiver_for(attribute) # steep:ignore
                 .cattri_variable_set(attribute.ivar, value, final: attribute.final?) # steep:ignore
        end

        return if attribute.expose == :none

        define_accessor!(attribute, context)
        define_writer!(attribute, context)
        define_predicate!(attribute, context) if attribute.with_predicate?
      end

      private

      # Defines a callable method that acts as both getter and setter.
      #
      # If called with no arguments, it returns the default (memoized).
      # If called with arguments, it processes the assignment and writes the value.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_accessor!(attribute, context)
        context.define_method(attribute) do |*args, **kwargs|
          receiver = context.storage_receiver_for(attribute, self)
          readonly_call = args.empty? && kwargs.empty?
          return AttributeCompiler.send(:memoize_default_value, receiver, attribute) if readonly_call

          attribute.validate_assignment!
          value = attribute.process_assignment(*args, **kwargs)
          receiver.cattri_variable_set(attribute.ivar, value) # steep:ignore
        end
      end

      # Defines a writer method `:name=`, assigning a transformed value to the backing store.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_writer!(attribute, context)
        context.define_method(attribute, name: :"#{attribute.name}=") do |value|
          receiver = context.storage_receiver_for(attribute, self)

          coerced_value = attribute.process_assignment(value)
          receiver.cattri_variable_set(attribute.ivar, coerced_value, final: attribute.final?) # steep:ignore
        end
      end

      # Defines a predicate method `:name?` that returns the truthiness of the value.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_predicate!(attribute, context)
        context.define_method(attribute, name: :"#{attribute.name}?") do
          !!send(attribute.name) # rubocop:disable Style/DoubleNegation
        end
      end

      # Returns the default value for the attribute, memoizing it in the backing store.
      #
      # @param receiver [Object] the instance or class receiving the value
      # @param attribute [Cattri::Attribute]
      # @return [Object] the stored or evaluated default
      def memoize_default_value(receiver, attribute)
        receiver.cattri_variable_memoize(attribute.ivar, final: attribute.final?) do
          attribute.evaluate_default
        end
      end
    end
  end
end
