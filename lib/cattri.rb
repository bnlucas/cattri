# frozen_string_literal: true

require_relative "cattri/version"
require_relative "cattri/visibility"
require_relative "cattri/class_attributes"
require_relative "cattri/instance_attributes"
require_relative "cattri/introspection"

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
# It also installs a custom `.inherited` hook to ensure that subclassed classes
# receive deep copies of attribute metadata and current values.
#
# Note: The `Cattri::Introspection` module must be included manually if needed.
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
    base.extend(Cattri::Visibility)
    base.extend(Cattri::ClassAttributes)
    base.include(Cattri::InstanceAttributes)

    base.singleton_class.define_method(:inherited) do |subclass|
      super(subclass) if defined?(super)

      %i[class instance].each do |type|
        Cattri.send(:copy_attributes_to, self, subclass, type)
      end
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
    # @param type [Symbol] either `:class` or `:instance`
    # @return [void]
    # @raise [Cattri::AttributeError] if an ivar copy operation fails
    def copy_attributes_to(origin, subclass, type)
      ivar = :"@__cattri_#{type}_attributes"
      attributes = origin.instance_variable_get(ivar) || {}

      subclass_attributes = attributes.transform_values do |attribute|
        copy_ivar_to(origin, subclass, attribute)
        attribute.dup
      end

      subclass.instance_variable_set(ivar, subclass_attributes)
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
    def copy_ivar_to(origin, subclass, attribute)
      value = duplicate_value(origin, attribute)
      subclass.instance_variable_set(attribute.ivar, value)
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
        puts "HERE"
        value
      end
    rescue StandardError => e
      raise Cattri::AttributeError, "Failed to duplicate value for attribute #{attribute}. Error: #{e.message}"
    end
  end
end
