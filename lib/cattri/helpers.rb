# frozen_string_literal: true

module Cattri
  # Internal support utilities for Cattri modules.
  #
  # Provides shared logic for safe default handling, attribute definition, and
  # consistent reset behavior across class-level and instance-level attributes.
  #
  # This module is intended for internal use only and is included by both
  # Cattri::ClassAttributes and Cattri::InstanceAttributes.
  module Helpers
    # A list of immutable Ruby types that are safe to reuse directly without duplication.
    #
    # These types are treated as-is when used as default values.
    #
    # @return [Array<Class>]
    SAFE_VALUE_TYPES = [Numeric, Symbol, TrueClass, FalseClass, NilClass].freeze

    protected

    # Defines an attribute structure used internally for accessors.
    #
    # Combines the caller's options with normalized default and setter logic,
    # and attaches a consistent `@ivar` key for storage.
    #
    # @param name [Symbol, String] The attribute name
    # @param options [Hash] The caller-provided options (e.g., `:default`, `:readonly`)
    # @param block [Proc, nil] Optional setter block
    # @param defaults [Hash] A set of fallback/default values to merge in
    # @return [Array] Normalized name and attribute definition hash
    def define_attribute(name, options, block, defaults)
      options[:default] = normalize_default(options[:default])
      options[:setter] = block || lambda { |*args, **kwargs|
        return kwargs unless kwargs.empty?
        return args.first if args.length == 1

        args
      }

      name = name.to_sym
      [name, defaults.merge(ivar: :"@#{name}", **options)]
    end

    # Wraps static default values in lambdas to ensure safety.
    #
    # If the value is already callable, it is returned as-is.
    # If the value is immutable, it is wrapped directly.
    # Otherwise, it is wrapped with `.dup` for safe reuse.
    #
    # @param default [Object, Proc, nil] The user-provided default value
    # @return [Proc] A proc that returns a safe default value
    def normalize_default(default)
      return default if default.respond_to?(:call)
      return -> { default } if default.frozen? || SAFE_VALUE_TYPES.any? { |type| default.is_a?(type) }

      -> { default.dup }
    end

    # Resets a set of attribute definitions on a target object.
    #
    # Used to restore class or instance attributes to their configured default values.
    #
    # @param target [Object] The object or class whose instance variables will be reset
    # @param attribute_definitions [Enumerable<Hash>] A list of attribute definition hashes
    # @return [void]
    def reset_attributes!(target, attribute_definitions)
      attribute_definitions.each do |definition|
        target.instance_variable_set(
          definition[:ivar],
          definition[:default].call
        )
      end
    end
  end
end
