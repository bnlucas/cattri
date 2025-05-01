# frozen_string_literal: true

module Cattri
  # Handles subclassing behavior for classes that use Cattri.
  #
  # This module installs a custom `.inherited` hook on the target class's singleton,
  # ensuring that attribute definitions and values are deep-copied to the subclass.
  #
  # The hook preserves any existing `.inherited` behavior defined on the class,
  # calling it before applying attribute propagation.
  module Inheritance
    # Installs an `inherited` hook on the given class.
    #
    # When the class is subclassed, Cattri will copy over attribute metadata and values
    # using the subclass’s context. This ensures subclass safety and definition isolation.
    #
    # Any pre-existing `.inherited` method is preserved and invoked first.
    #
    # @param base [Class] the class to install the hook on
    # @return [void]
    def self.install(base)
      singleton = base.singleton_class
      existing = singleton.instance_method(:inherited) rescue nil # rubocop:disable Style/RescueModifier

      singleton.define_method(:inherited) do |subclass|
        # :nocov:
        existing.bind(self).call(subclass) # steep:ignore
        # :nocov:

        context = Cattri::Context.new(subclass)
        attribute_registry.send(:copy_attributes_to, context) # steep:ignore
      end
    end
  end
end
