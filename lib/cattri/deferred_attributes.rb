# frozen_string_literal: true

require "set"

module Cattri
  # Cattri::DeferredAttributes enables modules to define both class-level and instance-level
  # attributes (via `cattr`, `iattr`, etc.) that are applied later when the module is
  # extended or included into a class.
  #
  # This deferral mechanism avoids method definition errors caused by attempting to define
  # class methods or instance methods directly on modules, which cannot be instantiated or
  # extended in the same way as classes.
  #
  # Deferred attributes are stored internally and applied to the final target (class or module)
  # during `include` or `extend` via lifecycle hooks.
  #
  # All deferred definitions preserve access control (`:public`, `:protected`, `:private`)
  # and support full method generation via the Cattri::AttributeCompiler API.
  #
  # This concern is automatically extended onto any module that defines deferred attributes
  # via Cattri.
  module DeferredAttributes
    # Prepend the {Hook} module into the singleton class of a module
    # to ensure deferred attributes are applied when the module is extended or included.
    #
    # @param base [Module] the module being extended
    # @return [void]
    def self.extended(base)
      return if base.singleton_class.ancestors.include?(Hook)

      base.singleton_class.prepend(Hook)
    end

    # Hook methods that trigger deferred attribute application
    # when the module is extended or included.
    module Hook
      # Applies deferred attributes to the including class or module.
      #
      # @param target [Class, Module]
      # @return [void]
      def included(target)
        apply_deferred_attributes(target) if respond_to?(:apply_deferred_attributes)
      end

      # Applies deferred attributes to the extending class or module.
      #
      # @param target [Class, Module]
      # @return [void]
      def extended(target)
        apply_deferred_attributes(target) if respond_to?(:apply_deferred_attributes)
      end
    end

    # Registers an attribute for deferred definition.
    #
    # @param attribute [Cattri::Attribute]
    # @return [void]
    def defer_attribute(attribute)
      deferred_attributes[attribute.level][attribute.name] = attribute
    end

    # Applies all deferred attributes to the given target class or module.
    #
    # This is triggered automatically when a module including Cattri is
    # extended or included.
    #
    # @param target [Class, Module]
    # @return [void]
    def apply_deferred_attributes(target)
      context = Cattri::Context.new(target)

      deferred_attributes.each do |level, attributes|
        level_accessor = :"#{level}_accessor"

        attributes.each_value do |attribute|
          Cattri::AttributeCompiler.send(level_accessor, attribute, context)
        end
      end
    end

    private

    # Stores all deferred attributes by level.
    #
    # @return [Hash{Symbol => Hash{Symbol => Cattri::Attribute}}]
    def deferred_attributes
      @deferred_attributes ||= Hash.new { |h, k| h[k] = {} }
    end
  end
end
