# frozen_string_literal: true

require "set"

module Cattri
  # Internal representation of a stored attribute value.
  AttributeValue = Struct.new(:value, :final)

  # Provides an internal storage mechanism for attribute values defined via `cattri`.
  #
  # This module is included into any class or module using Cattri and replaces
  # direct instance variable access with a namespaced store.
  #
  # It supports enforcement of `final` semantics and tracks explicit assignments.
  module InternalStore
    # Returns the list of attribute keys stored by Cattri on this object.
    #
    # Mimics Ruby's `#instance_variables`, but only includes attributes defined
    # via `cattri` and omits the leading `@` from names. All keys are returned as
    # frozen symbols (e.g., `:enabled` instead of `:@enabled`).
    #
    # @return [Array<Symbol>] the list of internally tracked attribute keys
    def cattri_variables
      __cattri_store.keys.freeze
    end

    # Checks whether the internal store contains a value for the given key.
    #
    # @param key [String, Symbol] the attribute name or instance variable
    # @return [Boolean] true if a value is present
    def cattri_variable_defined?(key)
      __cattri_store.key?(normalize_ivar(key))
    end

    # Fetches the value for a given attribute key from the internal store.
    #
    # @param key [String, Symbol] the attribute name or instance variable
    # @return [Object, nil] the stored value, or nil if not present
    def cattri_variable_get(key)
      __cattri_store[normalize_ivar(key)]&.value
    end

    # Sets a value in the internal store for the given attribute key.
    #
    # Enforces final semantics if a final value was already set.
    #
    # @param key [String, Symbol] the attribute name or instance variable
    # @param value [Object] the value to store
    # @param final [Boolean] whether the value should be locked as final
    # @return [Object] the stored value
    def cattri_variable_set(key, value, final: false)
      key = normalize_ivar(key)
      guard_final!(key)

      __cattri_store[key] = AttributeValue.new(value, final)
      __cattri_set_variables << key

      value
    end

    # Evaluates and sets a value for the given key only if it hasn't already been set.
    #
    # If a value is already present, it is returned as-is. Otherwise, the provided block
    # is called to compute the value, which is then stored. If `final: true` is passed,
    # the value is marked as final and cannot be reassigned.
    #
    # @param key [String, Symbol] the attribute name or instance variable
    # @param final [Boolean] whether to mark the value as final (immutable once set)
    # @yieldreturn [Object] the value to memoize if not already present
    # @return [Object] the existing or newly memoized value
    # @raise [Cattri::AttributeError] if attempting to overwrite a final value
    def cattri_variable_memoize(key, final: false)
      key = normalize_ivar(key)
      return cattri_variable_get(key) if cattri_variable_defined?(key)

      value = yield
      cattri_variable_set(key, value, final: final)
    end

    private

    # Returns the internal storage hash used for attribute values.
    #
    # @return [Hash<Symbol, Cattri::AttributeValue>]
    def __cattri_store
      @__cattri_store ||= {}
    end

    # Returns the set of attribute keys that have been explicitly assigned.
    #
    # @return [Set<Symbol>]
    def __cattri_set_variables
      @__cattri_set_variables ||= Set.new
    end

    # Normalizes the attribute key to a symbol without `@` prefix.
    #
    # @param key [String, Symbol]
    # @return [Symbol]
    def normalize_ivar(key)
      key.to_s.delete_prefix("@").to_sym.freeze
    end

    # Raises if attempting to modify a value that was marked as final.
    #
    # @param key [Symbol]
    # @raise [Cattri::AttributeError] if the key is final and already set
    def guard_final!(key)
      return unless cattri_variable_defined?(key)

      existing = __cattri_store[key]
      raise Cattri::AttributeError, "Cannot modify final attribute :#{key}" if existing.final
    end
  end
end
