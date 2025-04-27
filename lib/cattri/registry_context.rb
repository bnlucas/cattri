# frozen_string_literal: true

require_relative "attribute_registry"
require_relative "context"

module Cattri
  # Provides access to Cattri's attribute definition and context handling logic.
  #
  # This module is included into any class or module that uses Cattri, and is responsible
  # for instantiating and caching the `AttributeDefinitions` and `Context` objects used
  # to manage attribute declaration and method generation.
  #
  # The `attribute_registry` accessor exposes a per-class definition manager, which handles
  # attribute registration, duplication checks, deferrals, and reapplication.
  #
  # The `context` accessor provides the method generation context, including visibility
  # tracking and method scoping.
  module RegistryContext
    private

    # Returns the attribute definition registry for this class or module.
    #
    # This object is responsible for tracking all defined attributes by level,
    # applying them at runtime, and handling deferred definitions.
    #
    # @return [Cattri::AttributeRegistry]
    def attribute_registry
      @attribute_registry ||= Cattri::AttributeRegistry.new(context)
    end

    # Returns the method definition context for this class or module.
    #
    # This provides access to the visibility and scoping context in which
    # attribute-generated methods are defined.
    #
    # @return [Cattri::Context]
    def context
      @context ||= Context.new(self)
    end
  end
end
