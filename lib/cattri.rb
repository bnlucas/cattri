# frozen_string_literal: true

require_relative "cattri/attribute"
require_relative "cattri/context_registry"
require_relative "cattri/dsl"
require_relative "cattri/initializer_patch"
require_relative "cattri/internal_store"
require_relative "cattri/introspection"
require_relative "cattri/visibility"

# Main entrypoint for the Cattri DSL.
#
# When included in a class or module, this installs both class-level and instance-level
# attribute handling logic, visibility tracking, subclass inheritance propagation,
# and default value enforcement.
#
# It supports:
# - Defining class or instance attributes using `cattri` or `final_cattri`
# - Visibility tracking and method scoping
# - Write-once semantics for `final: true` attributes
# - Safe method generation with introspection support
module Cattri
  # Sets up the Cattri DSL on the including class or module.
  #
  # Includes internal storage and registry infrastructure into both the base and its singleton class,
  # prepends initialization logic, extends visibility and DSL handling, and installs the
  # subclassing hook to propagate attributes to descendants.
  #
  # @param base [Class, Module] the target that includes `Cattri`
  # @return [void]
  def self.included(base)
    [base, base.singleton_class].each do |mod|
      mod.include(Cattri::InternalStore)
      mod.include(Cattri::ContextRegistry)
      mod.instance_variable_set(:@__cattri_base_target, base)
    end

    base.extend(Cattri::InternalStore)
    base.singleton_class.extend(Cattri::InternalStore)

    base.prepend(Cattri::InitializerPatch)
    base.extend(Cattri::Visibility)
    base.extend(Cattri::Dsl)
    base.extend(ClassMethods)
  end

  # Provides opt-in class-level introspection support.
  #
  # This allows users to call methods like `.attribute_defined?`, `.attribute_methods`, etc.,
  # to inspect which attributes have been defined.
  module ClassMethods
    # Enables Cattri's attribute introspection methods on the current class.
    #
    # @return [void]
    def with_cattri_introspection
      include(Cattri::Introspection) # steep:ignore
    end
  end
end
