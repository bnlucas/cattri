# frozen_string_literal: true

module Cattri
  # Cattri::Visibility tracks the current method visibility context (`public`, `protected`, `private`)
  # when defining methods dynamically. It mimics Ruby's native visibility behavior so that
  # `cattri` definitions can automatically infer the intended access level based on the current context
  # in the source file.
  #
  # This module is intended to be extended by classes that include or extend Cattri.
  #
  # @example
  #   class MyClass
  #     include Cattri
  #
  #     private
  #     cattri :sensitive_data
  #   end
  #
  #   # => :sensitive_data will be defined as a private method
  module Visibility
    # Returns the currently active visibility scope on the class or module.
    #
    # Defaults to `:public` unless changed explicitly via `public`, `protected`, or `private`.
    #
    # @return [Symbol] :public, :protected, or :private
    def __cattri_visibility
      @__cattri_visibility ||= :public
    end

    # Intercepts calls to `public` to update the visibility tracker.
    #
    # If no method names are passed, this sets the current visibility scope for future methods.
    # Otherwise, delegates to Ruby’s native `Module#public`.
    #
    # @param args [Array<Symbol>] method names to make public, or empty to set context
    # @return [void]
    def public(*args)
      @__cattri_visibility = :public if args.empty?
      Module.instance_method(:public).bind(self).call(*args)
    end

    # Intercepts calls to `protected` to update the visibility tracker.
    #
    # If no method names are passed, this sets the current visibility scope for future methods.
    # Otherwise, delegates to Ruby’s native `Module#protected`.
    #
    # @param args [Array<Symbol>] method names to make protected, or empty to set context
    # @return [void]
    def protected(*args)
      @__cattri_visibility = :protected if args.empty?
      Module.instance_method(:protected).bind(self).call(*args)
    end

    # Intercepts calls to `private` to update the visibility tracker.
    #
    # If no method names are passed, this sets the current visibility scope for future methods.
    # Otherwise, delegates to Ruby’s native `Module#private`.
    #
    # @param args [Array<Symbol>] method names to make private, or empty to set context
    # @return [void]
    def private(*args)
      @__cattri_visibility = :private if args.empty?
      Module.instance_method(:private).bind(self).call(*args)
    end
  end
end
