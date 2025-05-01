# frozen_string_literal: true

require "set"

module Cattri
  # Provides support for defining attributes within a module that should be
  # applied later to any class or module that includes or extends it.
  #
  # This allows DSL modules to define Cattri attributes without prematurely
  # applying them to themselves, deferring application to the including/extending context.
  module DeferredAttributes
    # Hook into the module extension lifecycle to ensure deferred attributes are
    # applied when the module is included or extended.
    #
    # @param base [Module] the module that extended this module
    # @return [void]
    def self.extended(base)
      return if base.singleton_class.ancestors.include?(Hook)

      base.singleton_class.prepend(Hook)
    end

    # Hook methods for inclusion/extension that trigger deferred application.
    module Hook
      # Called when a module including `DeferredAttributes` is included into another module/class.
      #
      # @param target [Module] the including class or module
      # @return [void]
      def included(target)
        apply_deferred_attributes(target) if respond_to?(:apply_deferred_attributes) # steep:ignore
      end

      # Called when a module including `DeferredAttributes` is extended into another module/class.
      #
      # @param target [Module] the extending class or module
      # @return [void]
      def extended(target)
        apply_deferred_attributes(target) if respond_to?(:apply_deferred_attributes) # steep:ignore
      end
    end

    # Registers an attribute to be applied later when this module is included or extended.
    #
    # @param attribute [Cattri::Attribute] the attribute to defer
    # @return [void]
    def defer_attribute(attribute)
      deferred_attributes[attribute.name] = attribute
    end

    # Applies all deferred attributes to the target class or module.
    #
    # This is triggered automatically by the {Hook} on `included` or `extended`.
    #
    # @param target [Module] the class or module to apply the attributes to
    # @return [void]
    def apply_deferred_attributes(target)
      context = Cattri::Context.new(target)

      deferred_attributes.each_value do |attribute|
        Cattri::AttributeCompiler.define_accessor(attribute, context)
      end
    end

    private

    # Internal storage of deferred attributes for this module.
    #
    # @return [Hash{Symbol => Cattri::Attribute}]
    def deferred_attributes
      @deferred_attributes ||= {}
    end
  end
end
