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
      # Returns a hash of current class attribute values.
      #
      # @return [Hash<Symbol, Object>] a snapshot of each defined class attribute
      def snapshot_class_attributes
        return {} unless respond_to?(:class_attributes)

        class_attributes.each_with_object({}) do |attribute, hash|
          hash[attribute] = send(attribute)
        end.freeze
      end

      # @!method snapshot_cattrs
      #   Alias for {.snapshot_class_attributes}
      #   @see .snapshot_class_attributes
      alias snapshot_cattrs snapshot_class_attributes
    end

    # Returns a hash of current instance attribute values for this object.
    #
    # @return [Hash<Symbol, Object>] a snapshot of each defined instance attribute
    def snapshot_instance_attributes
      return {} unless self.class.respond_to?(:instance_attributes)

      self.class.instance_attributes.each_with_object({}) do |attribute, hash|
        hash[attribute] = send(attribute)
      rescue NoMethodError
        # Catch for write-only methods
        hash[attribute] = instance_variable_get(:"@#{attribute}")
      end
    end

    # @!method snapshot_iattrs
    #   Alias for {#snapshot_instance_attributes}
    #   @see #snapshot_instance_attributes
    alias snapshot_iattrs snapshot_instance_attributes
  end
end
