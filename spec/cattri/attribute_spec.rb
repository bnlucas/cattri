# frozen_string_literal: true

require "spec_helper"
require "cattri/attribute"

RSpec.describe Cattri::Attribute do
  describe "#initialize" do
    it "raises error for unsupported level" do
      expect do
        described_class.new(:foo, :bogus)
      end.to raise_error(Cattri::UnsupportedAttributeLevelError, /:bogus/)
    end

    it "uses default :public access and normalizes ivar" do
      attr = described_class.new(:name, :instance)
      expect(attr.access).to eq(:public)
      expect(attr.ivar).to eq(:@name)
    end

    it "respects explicit access and ivar" do
      attr = described_class.new(:foo, :instance, access: :protected, ivar: :bar)
      expect(attr.access).to eq(:protected)
      expect(attr.ivar).to eq(:@bar)
    end
  end

  describe "#[]" do
    it "delegates to #to_hash" do
      attr = described_class.new(:x, :class, access: :private)
      expect(attr[:access]).to eq(:private)
    end
  end

  describe "#to_hash / #to_h" do
    it "returns complete hash including typed options" do
      attr = described_class.new(:foo, :class, readonly: true)
      hash = attr.to_hash

      expect(hash).to include(
        name: :foo,
        level: :class,
        readonly: true,
        instance_reader: true
      )
    end
  end

  describe "#class_level?" do
    it "returns true" do
      attr = described_class.new(:foo, :class, readonly: true)

      expect(attr.class_level?).to eq(true)
      expect(attr.instance_level?).to eq(false)
    end
  end

  describe "#instance_level?" do
    it "returns true" do
      attr = described_class.new(:foo, :instance, reader: true)

      expect(attr.class_level?).to eq(false)
      expect(attr.instance_level?).to eq(true)
    end
  end

  describe "#final?" do
    [true, false].each do |state|
      it "return #{state} when instantiated with options[:final] = #{state}" do
        attribute = described_class.new(:foo, :class, final: state)
        expect(attribute.final?).to eq(state)
      end
    end
  end

  describe "#readonly?" do
    [true, false].each do |state|
      it "return #{state} when instantiated with options[:readonly] = #{state}" do
        attribute = described_class.new(:foo, :class, readonly: state)
        expect(attribute.readonly?).to eq(state)
      end
    end
  end

  describe "#readable?" do
    [
      [:class, {}, true],
      [:instance, { reader: true }, true],
      [:instance, { reader: false }, false]
    ].each do |level, options, expected|
      it "return #{expected} when instantiated with `#{level}, #{options}`" do
        attribute = described_class.new(:foo, level, **options)
        expect(attribute.readable?).to eq(expected)
      end
    end
  end

  describe "#writeable?" do
    [
      [{ final: false, readonly: false }, true],
      [{ final: true, readonly: false }, false],
      [{ final: true, readonly: true }, false]
    ].each do |options, expected|
      it "return #{expected} when instantiated with #{options}" do
        attribute = described_class.new(:foo, :class, **options)
        expect(attribute.writable?).to eq(expected)
      end
    end
  end

  describe "#invoke_default" do
    let(:attribute) { described_class.new(:foo, :class, default: -> { "default_value" }) }

    it "returns the default value" do
      result = attribute.invoke_default
      expect(result).to eq("default_value")
    end

    it "raises an error if the default value logic fails" do
      invalid_default = -> { raise StandardError, "Failed to generate default" }
      attribute_with_invalid_default = described_class.new(:foo, :class, default: invalid_default)

      expect do
        attribute_with_invalid_default.invoke_default
      end.to raise_error(Cattri::AttributeError, /Failed to evaluate the default value for :foo/)
    end
  end

  describe "#invoke_setter" do
    let(:attribute) { described_class.new(:foo, :class) }

    it "calls setter and assigns value" do
      setter = double("setter")
      allow(setter).to receive(:call).and_return("new value")

      attribute.instance_variable_set(:@setter, setter)

      result = attribute.invoke_setter("value")
      expect(result).to eq("new value")
      expect(setter).to have_received(:call).with("value")
    end

    it "raises AttributeError if setter fails" do
      setter = double("setter")
      allow(setter).to receive(:call).and_raise(StandardError, "Setter failed")

      attribute.instance_variable_set(:@setter, setter)

      expect do
        attribute.invoke_setter("value")
      end.to raise_error(Cattri::AttributeError, /Failed to evaluate the setter for :foo/)
    end

    it "raises an error when trying to invoke the setter on a finalized attribute" do
      attribute = described_class.new(:foo, :class, final: true)

      expect do
        attribute.invoke_setter("value")
      end.to raise_error(Cattri::FinalAttributeError, /Class attribute :#{attribute.name}/)
    end
  end

  describe "access level predicates" do
    it "returns true for public" do
      attr = described_class.new(:foo, :class, access: :public)
      expect(attr.public?).to eq(true)
    end

    it "returns true for protected" do
      attr = described_class.new(:foo, :class, access: :protected)
      expect(attr.protected?).to eq(true)
    end

    it "returns true for private" do
      attr = described_class.new(:foo, :class, access: :private)
      expect(attr.private?).to eq(true)
    end
  end

  describe "normalize_setter" do
    let(:attr) { described_class.new(:foo, :instance) }

    it "returns kwargs if present" do
      expect(attr.setter.call(1, a: 2)).to eq({ a: 2 })
    end

    it "returns single value if one positional arg" do
      expect(attr.setter.call("only")).to eq("only")
    end

    it "returns array of values for multiple args" do
      expect(attr.setter.call(1, 2, 3)).to eq([1, 2, 3])
    end
  end

  describe "normalize_default" do
    it "returns existing callable unchanged" do
      fn = -> { :ok }
      attr = described_class.new(:foo, :instance, default: fn)
      expect(attr.default).to eq(fn)
    end

    it "wraps immutable value in lambda" do
      attr = described_class.new(:foo, :instance, default: :sym)
      expect(attr.default.call).to eq(:sym)
    end

    it "wraps mutable values and duplicates them" do
      attr = described_class.new(:foo, :instance, default: [1, 2])
      v1 = attr.default.call
      v2 = attr.default.call
      expect(v1).to eq([1, 2])
      expect(v1).not_to be(v2)
    end

    it "raises an error if default value duplication fails" do
      invalid_default = double("invalid_default")
      allow(invalid_default).to receive(:dup).and_raise(TypeError, "Cannot duplicate object")

      invalid_attr = Cattri::Attribute.new(:foo, :class, default: invalid_default)

      expect do
        invalid_attr.default.call
      end.to raise_error(Cattri::AttributeError, /Failed to duplicate default value for :foo/)
    end
  end

  describe "level_options" do
    it "applies correct class defaults" do
      attr = described_class.new(:foo, :class)
      expect(attr.to_h[:instance_reader]).to eq(true)
    end

    it "applies correct instance defaults" do
      attr = described_class.new(:bar, :instance)
      expect(attr.to_h).to include(readonly: false, writer: true)
    end

    it "sets options[:writer] to false for final instance-level attributes" do
      attr = described_class.new(:bar, :instance, final: true, writer: true)
      expect(attr.to_h).to include(final: true, writer: false)
    end

    it "sets options[:readonly] to true for instance-level attributes where reader == true and writer == false" do
      attr = described_class.new(:bar, :instance, reader: true, writer: false)
      expect(attr.to_h).to include(readonly: true, reader: true, writer: false)
    end
  end

  describe "guard_writable!" do
    it "doesn't raise on non-final, non-readonly attributes" do
      attr = described_class.new(:foo, :instance)
      expect { attr.guard_writable! }.to_not raise_error
    end

    it "raises on finalized attributes" do
      attr = described_class.new(:foo, :instance, final: true)
      expect do
        attr.guard_writable!
      end.to raise_error(Cattri::FinalAttributeError, /Instance attribute :#{attr.name}/)
    end

    it "raises on readonly class attributes" do
      attr = described_class.new(:foo, :class, readonly: true)
      expect do
        attr.guard_writable!
      end.to raise_error(Cattri::ReadonlyAttributeError, /Class attribute :#{attr.name}/)
    end

    it "raises on readonly instance attributes" do
      attr = described_class.new(:foo, :instance, reader: true, writer: false)
      expect do
        attr.guard_writable!
      end.to raise_error(Cattri::ReadonlyAttributeError, /Instance attribute :#{attr.name}/)
    end
  end
end
