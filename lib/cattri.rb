# frozen_string_literal: true

require_relative "cattri/class_attributes"
require_relative "cattri/registry_context"
require_relative "cattri/instance_attributes"
require_relative "cattri/introspection"
require_relative "cattri/visibility"
require_relative "cattri/version"

# The primary entry point for the Cattri gem.
#
# When included, it enables both class-level and instance-level attribute definitions
# via `cattr` and `iattr`-style DSLs, providing a lightweight alternative to traditional
# `attr_*` and `cattr_*` patterns.
#
# The module includes:
# - `Cattri::ClassAttributes` (for class-level configuration)
# - `Cattri::InstanceAttributes` (for instance-level configuration)
# - `Cattri::Visibility` (for default access control)
#
# It also installs a custom `.inherited` hook to ensure subclassed classes receive
# deep copies of attribute definitions *and* current backing values. This guarantees
# isolation and safe mutation across inheritance hierarchies.
#
# All attribute metadata is managed via `Cattri::AttributeRegistry`, accessible
# internally via the `attribute_registry` method (provided by `Cattri::RegistryContext`).
#
# Note: The `Cattri::Introspection` module must be included manually if introspection
# helpers are desired in development or test environments.
#
# @example Using both class and instance attributes
#   class Config
#     include Cattri
#
#     cattr :enabled, default: true
#     iattr :name, default: "anonymous"
#   end
#
#   Config.enabled          # => true
#   Config.new.name         # => "anonymous"
module Cattri
  # Hook triggered when `include Cattri` is called.
  #
  # Installs core attribute DSLs and visibility settings into the host class.
  # Also injects `.inherited` logic to propagate attribute metadata to subclasses.
  #
  # @param base [Class, Module] the receiving class or module
  # @return [void]
  def self.included(base)
    base.include(Cattri::RegistryContext)
    base.singleton_class.include(Cattri::RegistryContext)

    base.extend(Cattri::Visibility)
    base.extend(Cattri::ClassAttributes)
    base.include(Cattri::InstanceAttributes)
    base.extend(ClassMethods)

    base_singleton = base.singleton_class
    existing_inherited = base_singleton.instance_method(:inherited) rescue nil # rubocop:disable Style/RescueModifier

    base_singleton.define_method(:inherited) do |subclass|
      # :nocov:
      existing_inherited&.bind(self)&.call(subclass)
      # :nocov:

      %i[class instance].each do |level|
        Cattri.send(:copy_attributes_to, self, subclass, level)
      end
    end
  end

  # Class-level methods
  module ClassMethods
    # Enables introspection support by including Cattri::Introspection.
    def with_cattri_introspection
      include(Cattri::Introspection)
    end
  end

  class << self
    private

    # Copies attribute definitions and backing values from one class to a subclass.
    #
    # This is invoked automatically via the `.inherited` hook to ensure
    # subclass isolation and metadata integrity.
    #
    # @param origin [Class] the parent class
    # @param subclass [Class] the child class inheriting the attributes
    # @param level [Symbol] either `:class` or `:instance`
    # @return [void]
    # @raise [Cattri::AttributeError] if an ivar copy operation fails
    def copy_attributes_to(origin, subclass, level)
      origin_registry = origin.send(:attribute_registry).defined_attributes(level)
      copied_attributes = origin_registry.values.map do |attribute|
        copy_attribute_to(origin, subclass, attribute)
      end

      subclass_context = Cattri::Context.new(subclass)
      subclass_registry = subclass.send(:attribute_registry)
      subclass_registry.send(:apply_copied_attributes, *copied_attributes, target_context: subclass_context)
    end

    # Duplicates the current value of an attribute's backing ivar to the subclass.
    #
    # Falls back to raw assignment if duplication is not supported.
    #
    # @param origin [Class] the parent class
    # @param subclass [Class] the receiving subclass
    # @param attribute [Cattri::Attribute]
    # @return [void]
    # @raise [Cattri::AttributeError] if the value cannot be safely duplicated
    def copy_attribute_to(origin, subclass, attribute)
      copied_attribute = attribute.dup.freeze
      value = duplicate_value(origin, attribute)
      subclass.instance_variable_set(copied_attribute.ivar, value)

      copied_attribute
    end

    # Attempts to duplicate the value of an attribute's backing ivar.
    #
    # This method first tries to duplicate the value stored in the ivar.
    # If duplication is not supported due to the object's nature (e.g., it is frozen or immutable),
    # it will fall back to returning the original value.
    #
    # @param origin [Class] the parent class from which the ivar value is being retrieved
    # @param attribute [Cattri::Attribute] the attribute for which the ivar value is being duplicated
    # @return [Object] the duplicated value or the original value if duplication is not possible
    # @raise [Cattri::AttributeError] if duplication fails due to unsupported object types
    def duplicate_value(origin, attribute)
      value = origin.instance_variable_get(attribute.ivar)

      begin
        value.dup
      rescue TypeError, FrozenError
        value
      end
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to duplicate value for attribute #{attribute}. Error: #{e.message}"
    end
  end
end
