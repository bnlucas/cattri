# frozen_string_literal: true

module Cattri
  # Provides the primary DSL for defining class-level and instance-level attributes.
  #
  # This module is extended into any class or module that includes Cattri,
  # and exposes methods like `cattri` and `final_cattri` for concise attribute declaration.
  #
  # All attributes are defined through the underlying attribute registry and
  # are associated with method accessors (reader, writer, predicate) based on options.
  module Dsl
    # Defines a new attribute with optional default, coercion, and visibility options.
    #
    # The attribute can be defined with a static value, a lazy-evaluated block,
    # or with additional options like `final`, `predicate`, or `expose`.
    #
    # The attribute will be defined as either class-level or instance-level
    # depending on the `scope:` option.
    #
    # @param name [Symbol, String] the attribute name
    # @param value [Object, nil] optional static value or default
    # @param options [Hash] additional attribute configuration
    # @option options [Boolean] :scope whether this is a class-level (:class) or instance-level (:instance) attribute
    # @option options [Boolean] :final whether the attribute is write-once
    # @option options [Boolean] :predicate whether to define a predicate method
    # @option options [Symbol] :expose whether to expose `:read`, `:write`, `:read_write`, or `:none`
    # @option options [Symbol] :visibility the visibility for generated methods (`:public`, `:protected`, `:private`)
    # @yield optional block to lazily evaluate the attribute’s default value
    # @return [Array<Symbol>] the defined methods
    def cattri(name, value = nil, **options, &block)
      options = { visibility: __cattri_visibility }.merge(options) # steep:ignore
      attribute_registry.define_attribute(name, value, **options, &block) # steep:ignore
    end

    # Defines a write-once (final) attribute.
    #
    # Final attributes can be written only once and raise on re-assignment.
    # This is equivalent to `cattri(..., final: true)`.
    #
    # @param name [Symbol, String] the attribute name
    # @param value [Object, nil] static or lazy default value
    # @param options [Hash] additional attribute configuration
    # @option options [Boolean] :scope whether this is a class-level (:class) or instance-level (:instance) attribute
    # @option options [Boolean] :final whether the attribute is write-once
    # @option options [Boolean] :predicate whether to define a predicate method
    # @option options [Symbol] :expose whether to expose `:read`, `:write`, `:read_write`, or `:none`
    # @option options [Symbol] :visibility the visibility for generated methods (`:public`, `:protected`, `:private`)
    # @yield optional block to lazily evaluate the default
    # @return [Array<Symbol>] the defined methods
    def final_cattri(name, value, **options, &block)
      cattri(name, value, **options.merge(final: true), &block) # steep:ignore
    end
  end
end
