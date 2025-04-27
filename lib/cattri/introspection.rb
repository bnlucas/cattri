# frozen_string_literal: true

module Cattri
  # Adds debugging and inspection helpers for reading the current values of
  # class- and instance-level attributes defined via Cattri.
  #
  # This module is intended for use in development and test environments to
  # help capture attribute state at a given moment.
  #
  # It can be included in any class or module that uses {Cattri::ClassAttributes}
  # or {Cattri::InstanceAttributes}.
  #
  # @example
  #   class MyConfig
  #     extend Cattri::ClassAttributes
  #     include Cattri::Introspection
  #
  #     cattr :items, default: []
  #   end
  #
  #   MyConfig.items << :a
  #   MyConfig.snapshot_class_attributes #=> { items: [:a] }
  module Introspection
    # Hook called when the module is included. Extends the base with class methods.
    #
    # @param base [Class, Module]
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods for introspection.
    module ClassMethods
      # Checks whether a class attribute has been defined.
      #
      # @param name [Symbol]
      # @return [Boolean]
      def class_attribute_defined?(name)
        attribute_registry.defined_attributes(:class, with_ancestors: true).key?(name.to_sym)
      end

      # Returns the full attribute definition object.
      #
      # @param name [Symbol]
      # @return [Cattri::Attribute, nil]
      def class_attribute_definition(name)
        attribute_registry.defined_attributes(:class, with_ancestors: true)[name.to_sym]
      end

      # Checks if an instance-level attribute has been defined.
      #
      # @param name [Symbol, String]
      # @return [Boolean]
      def instance_attribute_defined?(name)
        attribute_registry.defined_attributes(:instance, with_ancestors: true).key?(name.to_sym)
      end

      # Returns the full attribute definition for a given name.
      #
      # @param name [Symbol, String]
      # @return [Cattri::Attribute, nil]
      def instance_attribute_definition(name)
        attribute_registry.defined_attributes(:instance, with_ancestors: true)[name.to_sym]
      end

      # Returns a frozen hash of current class attribute values.
      #
      # @return [Hash<Symbol, Object>] a snapshot of each defined class attribute
      def snapshot_class_attributes
        return {} unless respond_to?(:class_attributes)

        class_attributes.each_with_object({}) do |attribute_name, hash|
          hash[attribute_name] = send(attribute_name)
        end.freeze
      end

      # @!method cattr_defined?(name)
      #   Alias for {.class_attribute_defined?}
      #   @param name [Symbol]
      #   @return [Boolean]
      alias cattr_defined? class_attribute_defined?

      # @!method cattr_definition(name)
      #   Alias for {.class_attribute_definition}
      #   @param name [Symbol]
      #   @return [Cattri::Attribute, nil]
      alias cattr_definition class_attribute_definition

      # @!method iattr_defined?(name)
      #   Alias for {#instance_attribute_defined?}
      #   @see #instance_attribute_defined?
      alias iattr_defined? instance_attribute_defined?

      # @!method iattr_definition(name)
      #   Alias for {#instance_attribute_definition}
      #   @see #instance_attribute_definition
      alias iattr_definition instance_attribute_definition

      # @!method snapshot_cattrs
      #   Alias for {.snapshot_class_attributes}
      #   @see .snapshot_class_attributes
      alias snapshot_cattrs snapshot_class_attributes
    end

    # Returns a frozen hash of current instance attribute values for this object.
    #
    # @return [Hash<Symbol, Object>] a snapshot of each defined instance attribute
    def snapshot_instance_attributes # rubocop:disable Metrics/AbcSize
      return {} unless self.class.respond_to?(:instance_attributes)

      self.class.instance_attributes.each_with_object({}) do |attribute_name, hash|
        hash[attribute_name] = send(attribute_name)
      rescue NoMethodError
        # Catch for write-only methods
        attribute = self.class.instance_attribute_definition(attribute_name)
        value = attribute.invoke_default unless instance_variable_defined?(attribute.ivar)
        value ||= instance_variable_get(attribute.ivar)

        hash[attribute_name] = value
      end.freeze
    end

    # @!method snapshot_iattrs
    #   Alias for {#snapshot_instance_attributes}
    #   @see #snapshot_instance_attributes
    alias snapshot_iattrs snapshot_instance_attributes
  end
end
