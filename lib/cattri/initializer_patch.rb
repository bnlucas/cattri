# frozen_string_literal: true

module Cattri
  # Provides a patch to `#initialize` that ensures all final attributes
  # are initialized with their default values if not already set.
  #
  # This module is prepended into Cattri-including classes to enforce
  # write-once semantics for instance-level `final: true` attributes.
  #
  # @example
  #   class MyClass
  #     include Cattri
  #
  #     cattri :id, -> { SecureRandom.uuid }, final: true
  #   end
  #
  #   MyClass.new # => will have a UUID assigned to @id unless explicitly set
  module InitializerPatch
    # Hooked constructor that initializes final attributes using their defaults
    # if no value has been set by the user.
    #
    # @param args [Array] any positional arguments passed to initialize
    # @param kwargs [Hash] any keyword arguments passed to initialize
    # @yield an optional block to pass to `super`
    # @return [void]
    def initialize(*args, **kwargs, &block)
      super

      registry = self.class.send(:attribute_registry)
      registry.defined_attributes(with_ancestors: true).each_value do |attribute| # steep:ignore
        next if cattri_variable_defined?(attribute.ivar) # steep:ignore
        next unless attribute.final?

        cattri_variable_set(attribute.ivar, attribute.evaluate_default) # steep:ignore
      end
    end
  end
end
