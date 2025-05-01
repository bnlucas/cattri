# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::InternalStore do
  let(:klass) do
    Class.new do
      include Cattri::InternalStore

      public :normalize_ivar, :__cattri_store, :__cattri_set_variables
    end
  end

  subject(:instance) { klass.new }

  describe "#cattri_variable_defined?" do
    it "returns false when variable is not set" do
      expect(instance.cattri_variable_defined?(:foo)).to be false
    end

    it "returns true when variable is set" do
      instance.cattri_variable_set(:foo, 123)
      expect(instance.cattri_variable_defined?(:foo)).to be true
    end
  end

  describe "#cattri_variable_get" do
    it "returns nil when variable is not set" do
      expect(instance.cattri_variable_get(:bar)).to be_nil
    end

    it "returns the value when variable is set" do
      instance.cattri_variable_set(:bar, "hello")
      expect(instance.cattri_variable_get(:bar)).to eq("hello")
    end
  end

  describe "#cattri_variable_set" do
    it "sets the value for a variable" do
      instance.cattri_variable_set(:baz, 42)
      expect(instance.cattri_variable_get(:baz)).to eq(42)
    end

    it "tracks the variable as explicitly set" do
      instance.cattri_variable_set(:baz, 42)
      expect(instance.__cattri_set_variables).to include(:baz)
    end

    it "normalizes the key (removes @ and converts to symbol)" do
      instance.cattri_variable_set("@qux", 99)
      expect(instance.__cattri_store).to have_key(:qux)
    end

    it "raises if modifying a final value" do
      instance.cattri_variable_set(:locked, "a", final: true)

      expect do
        instance.cattri_variable_set(:locked, "b", final: true)
      end.to raise_error(Cattri::AttributeError, /Cannot modify final attribute :locked/)
    end
  end

  describe "#cattri_variable_memoize" do
    it "memoizes value if not already set" do
      result = instance.cattri_variable_memoize(:lazy) { "computed" }

      expect(result).to eq("computed")
      expect(instance.cattri_variable_get(:lazy)).to eq("computed")
    end

    it "returns existing value if already set" do
      instance.cattri_variable_set(:lazy, "preset")
      result = instance.cattri_variable_memoize(:lazy) { "should not run" }

      expect(result).to eq("preset")
    end
  end

  describe "#__cattri_store" do
    it "returns a Hash" do
      expect(instance.__cattri_store).to be_a(Hash)
    end

    it "memoizes the store" do
      expect(instance.__cattri_store).to equal(instance.__cattri_store)
    end
  end

  describe "#__cattri_set_variables" do
    it "returns a Set" do
      expect(instance.__cattri_set_variables).to be_a(Set)
    end

    it "memoizes the set" do
      expect(instance.__cattri_set_variables).to equal(instance.__cattri_set_variables)
    end
  end

  describe "#normalize_ivar" do
    it "converts string with @ to symbol without @" do
      expect(instance.normalize_ivar("@name")).to eq(:name)
    end

    it "converts plain string to symbol" do
      expect(instance.normalize_ivar("email")).to eq(:email)
    end

    it "converts symbol to symbol" do
      expect(instance.normalize_ivar(:age)).to eq(:age)
    end

    it "freezes the returned symbol" do
      sym = instance.normalize_ivar("cool")
      expect(sym).to be_frozen
    end
  end

  describe "#guard_final!" do
    it "raises if key is defined and final" do
      instance.__cattri_store[:foo] = Cattri::AttributeValue.new("sealed", true)
      expect do
        instance.send(:guard_final!, :foo)
      end.to raise_error(Cattri::AttributeError, /Cannot modify final attribute :foo/)
    end

    it "does nothing if key is not defined" do
      expect do
        instance.send(:guard_final!, :bar)
      end.not_to raise_error
    end

    it "does nothing if key is defined but not final" do
      instance.__cattri_store[:baz] = Cattri::AttributeValue.new("open", false)
      expect do
        instance.send(:guard_final!, :baz)
      end.not_to raise_error
    end
  end
end
