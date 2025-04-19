# frozen_string_literal: true

require_relative "cattri/version"
require_relative "cattri/class_attributes"
require_relative "cattri/instance_attributes"
require_relative "cattri/introspection"

# The primary entry point for the Cattri gem.
#
# When included, it adds support for both class-level and instance-level
# attribute declarations using `cattr` and `iattr` style methods.
#
# This module does **not** include introspection helpers by default —
# use `include Cattri::Introspection` explicitly if needed.
#
# @example Using both class and instance attributes
#   class MyConfig
#     include Cattri
#
#     cattr :enabled, default: true
#     iattr :name, default: "anonymous"
#   end
#
#   MyConfig.enabled # => true
#   MyConfig.new.name # => "anonymous"
module Cattri
  # Hook triggered when `include Cattri` is called.
  # Adds class and instance attribute support to the target.
  #
  # @param base [Class, Module] the receiving class or module
  # @return [void]
  def self.included(base)
    base.extend(Cattri::ClassAttributes)
    base.include(Cattri::InstanceAttributes)
  end
end
