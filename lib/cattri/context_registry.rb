# frozen_string_literal: true

require_relative "attribute_registry"
require_relative "context"

module Cattri
  # Provides per-class or per-module access to the attribute registry and method definition context.
  #
  # This module is included into both the base and singleton class of any class using Cattri.
  # It initializes and exposes a lazily-evaluated `attribute_registry` and `context` specific
  # to the current scope, enabling safe and isolated attribute handling.
  module ContextRegistry
    private

    # Returns the attribute definition registry for this class or module.
    #
    # The registry is responsible for tracking all defined attributes, both class-level and
    # instance-level, handling application logic, and copying across subclasses where needed.
    #
    # @return [Cattri::AttributeRegistry] the registry used to define and apply attributes
    def attribute_registry
      @attribute_registry ||= Cattri::AttributeRegistry.new(context)
    end

    # Returns the method definition context for this class or module.
    #
    # The context wraps the current target (class or module) and provides utilities
    # for defining attribute methods (readers, writers, predicates), managing visibility,
    # and recording declared methods to avoid duplication.
    #
    # @return [Cattri::Context] the context used for method definition and visibility tracking
    def context
      base = instance_variable_get(:@__cattri_base_target) || self
      @context ||= Context.new(base) # steep:ignore
    end
  end
end
