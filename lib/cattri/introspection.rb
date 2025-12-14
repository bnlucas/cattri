# frozen_string_literal: true

require "set"

module Cattri
  # Provides a read-only interface for inspecting attributes defined via the Cattri DSL.
  #
  # When included, adds class-level methods to:
  # - Check if an attribute is defined
  # - Retrieve attribute definitions
  # - List defined attribute methods
  # - Trace the origin of an attribute
  module Introspection
    # @param base [Class, Module] the target that includes `Cattri`
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
    end

    # @api public
    # Class-level introspection methods exposed via `.attribute_defined?`, `.attribute`, etc.
    module ClassMethods
      # Returns true if the given attribute has been defined on this class or any ancestor.
      #
      # @param name [Symbol, String] the attribute name
      # @return [Boolean]
      def attribute_defined?(name)
        !!attribute(name)
      end

      # Returns the attribute definition for the given name.
      #
      # Includes inherited definitions if available.
      #
      # @param name [Symbol, String] the attribute name
      # @return [Cattri::Attribute, nil]
      def attribute(name)
        attribute_registry.defined_attributes(with_ancestors: true)[name.to_sym] # steep:ignore
      end

      # Returns a list of attribute names defined on this class.
      #
      # Includes inherited attributes if `with_ancestors` is true.
      #
      # @param with_ancestors [Boolean]
      # @return [Array<Symbol>]
      def attributes(with_ancestors: false)
        attribute_registry.defined_attributes(with_ancestors: with_ancestors).keys # steep:ignore
      end

      # Returns a hash of attribute definitions defined on this class.
      #
      # Includes inherited attributes if `with_ancestors` is true.
      #
      # @param with_ancestors [Boolean]
      # @return [Hash{Symbol => Cattri::Attribute}]
      def attribute_definitions(with_ancestors: false)
        attribute_registry.defined_attributes(with_ancestors: with_ancestors) # steep:ignore
      end

      # Returns a hash of all methods defined by Cattri attributes.
      #
      # This includes accessors, writers, and predicates where applicable.
      #
      # @return [Hash{Symbol => Set<Symbol>}]
      def attribute_methods
        attribute_registry.defined_attributes(with_ancestors: true).transform_values do |attribute| # steep:ignore
          Set.new(attribute.allowed_methods)
        end
      end

      # Returns the original class or module where the given attribute was defined.
      #
      # @param name [Symbol, String] the attribute name
      # @return [Module, nil]
      def attribute_source(name)
        attribute(name)&.defined_in
      end
    end
  end
end
