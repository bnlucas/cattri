# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Helpers do
  subject(:helper) do
    Class.new do
      extend Cattri::Helpers
    end
  end

  let(:attr_class) do
    Class.new do
      include Cattri

      cattr :enabled, default: true
      iattr :name, default: :anonymous do |value|
        value.to_s.downcase.to_sym
      end
    end
  end

  describe "#define_attribute" do
    let(:defaults) { { readonly: false } }

    it "returns a name and attribute definition hash" do
      name, definition = helper.send(:define_attribute, helper, :foo, { default: 123 }, nil, defaults)

      expect(name).to eq(:foo)
      expect(definition).to include(
        ivar: :@foo,
        default: be_a(Proc),
        setter: be_a(Proc),
        readonly: false
      )
      expect(definition[:default].call).to eq(123)
      expect(definition[:setter].call("test")).to eq("test")
    end

    it "wraps multi-arg setters into an array" do
      _, definition = helper.send(:define_attribute, helper, :list, {}, nil, {})

      expect(definition[:setter].call(:a, :b)).to eq(%i[a b])
    end

    it "unwraps single-arg setters to the value directly" do
      _, definition = helper.send(:define_attribute, helper, :val, {}, nil, {})

      expect(definition[:setter].call(:only)).to eq(:only)
    end

    it "uses kwargs if only kwargs are given" do
      _, definition = helper.send(:define_attribute, helper, :kwarg, {}, nil, {})

      expect(definition[:setter].call(foo: 1)).to eq({ foo: 1 })
    end

    it "uses the provided block as setter if given" do
      block = lambda(&:upcase)

      _, definition = helper.send(:define_attribute, helper, :custom, {}, block, {})
      expect(definition[:setter].call("ok")).to eq("OK")
    end
  end

  describe "#normalize_default" do
    it "returns callables as-is" do
      fn = -> { 42 }
      result = helper.send(:normalize_default, fn)

      expect(result).to equal(fn)
      expect(result.call).to eq(42)
    end

    it "wraps immutable values in a proc" do
      result = helper.send(:normalize_default, :symbol)

      expect(result).to be_a(Proc)
      expect(result.call).to eq(:symbol)
    end

    it "wraps frozen objects in a proc" do
      frozen_val = "static"
      result = helper.send(:normalize_default, frozen_val)

      expect(result.call).to eq("static")
    end

    it "wraps mutable values in a proc that dupes them" do
      array = [1, 2, 3]
      result = helper.send(:normalize_default, array)

      expect(result.call).to eq([1, 2, 3])
      expect(result.call).not_to be(array)
    end
  end

  describe "#reset_attributes!" do
    let(:target) { Struct.new(:foo, :bar).new }
    let(:attributes) do
      [
        {
          ivar: :@foo,
          default: -> { "foo-default" }
        },
        {
          ivar: :@bar,
          default: -> { 42 }
        }
      ]
    end

    it "sets each instance variable to its default value" do
      target.instance_variable_set(:@foo, "old")
      target.instance_variable_set(:@bar, 99)

      helper.send(:reset_attributes!, target, attributes)

      expect(target.instance_variable_get(:@foo)).to eq("foo-default")
      expect(target.instance_variable_get(:@bar)).to eq(42)
    end

    it "overwrites unset instance variables" do
      expect(target.instance_variable_defined?(:@foo)).to be false
      helper.send(:reset_attributes!, target, attributes)

      expect(target.instance_variable_get(:@foo)).to eq("foo-default")
    end
  end
end
