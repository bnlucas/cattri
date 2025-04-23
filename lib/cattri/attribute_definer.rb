# frozen_string_literal: true

module Cattri
  # Defines attribute accessors on a given target class using Cattri's Context.
  #
  # This class provides a set of utility methods to generate reader and writer
  # methods dynamically, with support for default values, coercion, and memoization.
  #
  # All accessors are defined through the Cattri::Context abstraction to ensure
  # consistent scoping, visibility, and method tracking.
  class AttributeDefiner
    class << self
      # Defines a callable accessor for class-level attributes.
      #
      # The generated method:
      # - Returns the memoized default value when called with no args or if readonly
      # - Otherwise, calls the attribute’s setter and memoizes the result
      #
      # If the attribute is not readonly, a writer (`foo=`) is also defined.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      # @raise [Cattri::AttributeError] if the setter raises an error
      def define_callable_accessor(attribute, context)
        return unless attribute.class_level?

        context.define_method(attribute) do |*args, **kwargs|
          readonly = (args.empty? && kwargs.empty?) || attribute[:readonly]
          return AttributeDefiner.send(:memoize_default_value, self, attribute) if readonly

          value = attribute.invoke_setter(*args, **kwargs)
          instance_variable_set(attribute.ivar, value)
        end

        define_writer(attribute, context) unless attribute[:readonly]
      end

      # Defines an instance-level reader for class-level attributes.
      #
      # This method delegates the instance-level call to the class method.
      # It is used when `instance_reader: true` is specified.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_instance_level_reader(attribute, context)
        return unless attribute.class_level?

        define_instance_level_method(attribute, context) do
          self.class.__send__(attribute.name)
        end

        context.send(:apply_access, attribute.name, attribute)
      end

      # Defines an instance-level method for a class-level attribute.
      #
      # This is a shared utility for defining instance methods that delegate to class attributes,
      # including both regular readers and predicate-style readers (`predicate: true`).
      #
      # Visibility is inherited from the attribute and applied to the defined method.
      #
      # @param attribute [Cattri::Attribute] the associated attribute metadata
      # @param context [Cattri::Context] the context in which to define the method
      # @param name [Symbol, nil] optional override for the method name (defaults to `attribute.name`)
      # @yield the method body to define
      # @return [void]
      def define_instance_level_method(attribute, context, name: nil, &block)
        name = (name || attribute.name).to_sym
        context.target.define_method(name, &block)

        context.send(:apply_access, name, attribute)
      end

      # Defines standard reader and writer methods for instance-level attributes.
      #
      # Skips definition if `reader: false` or `writer: false` is specified.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_accessor(attribute, context)
        define_reader(attribute, context) if attribute[:reader]
        define_writer(attribute, context) if attribute[:writer]
      end

      # Defines a memoizing reader for the given attribute.
      #
      # This is used for both class and instance attributes, and ensures that
      # the default value is computed only once and stored in the ivar.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_reader(attribute, context)
        context.define_method(attribute) do
          AttributeDefiner.send(:memoize_default_value, self, attribute)
        end
      end

      # Defines a writer method (`foo=`) that sets and coerces a value via the attribute setter.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_writer(attribute, context)
        context.define_method(attribute, name: :"#{attribute.name}=") do |value|
          coerced_value = attribute.setter.call(value)
          instance_variable_set(attribute.ivar, coerced_value)
        end
      end

      # Defines, or redefines, a writer method (`foo=`) that sets and coerces a value via the attribute setter.
      #
      # @param attribute [Cattri::Attribute]
      # @param context [Cattri::Context]
      # @return [void]
      def define_writer!(attribute, context)
        context.define_method!(attribute, name: :"#{attribute.name}=") do |value|
          coerced_value = attribute.setter.call(value)
          instance_variable_set(attribute.ivar, coerced_value)
        end
      end

      private

      # Returns the memoized value for an attribute or computes it from the default.
      #
      # This helper ensures lazy initialization while guarding against errors in the default proc.
      #
      # @param receiver [Object]
      # @param attribute [Cattri::Attribute]
      # @return [Object]
      # @raise [Cattri::AttributeError] if the default block raises an error
      def memoize_default_value(receiver, attribute)
        return receiver.instance_variable_get(attribute.ivar) if receiver.instance_variable_defined?(attribute.ivar)

        receiver.instance_variable_set(attribute.ivar, attribute.invoke_default)
      end
    end
  end
end
