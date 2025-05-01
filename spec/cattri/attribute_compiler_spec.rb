# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::AttributeCompiler do
  let(:dummy_class) do
    Class.new do
      include Cattri
    end
  end

  let(:context) { dummy_class.send(:context) }

  describe ".define_accessor" do
    context "when attribute is final and class-level" do
      let(:attribute) do
        Cattri::Attribute.new(
          :count,
          defined_in: dummy_class,
          scope: :class,
          final: true,
          default: -> { 100 },
          expose: :read_write
        )
      end

      it "eagerly sets the default value on the target class" do
        described_class.define_accessor(attribute, context)
        expect(dummy_class.cattri_variable_get(:count)).to eq(100)
      end
    end

    context "when expose is :none" do
      let(:attribute) do
        Cattri::Attribute.new(
          :secret,
          defined_in: dummy_class,
          default: -> { "hidden" },
          expose: :none
        )
      end

      it "does not define any methods" do
        described_class.define_accessor(attribute, context)
        instance = dummy_class.new
        expect(instance).not_to respond_to(:secret)
      end
    end

    context "when expose is :read_write with predicate" do
      let(:attribute) do
        Cattri::Attribute.new(
          :enabled,
          defined_in: dummy_class,
          default: -> { false },
          predicate: true,
          expose: :read_write
        )
      end

      it "defines reader, writer, and predicate methods" do
        described_class.define_accessor(attribute, context)
        instance = dummy_class.new

        expect(instance.enabled).to eq(false)
        instance.enabled = true
        expect(instance.enabled?).to eq(true)
      end
    end
  end

  describe ".define_accessor!" do
    let(:attribute) do
      Cattri::Attribute.new(
        :setting,
        defined_in: dummy_class,
        default: -> { "default" },
        expose: :read_write
      )
    end

    it "defines a reader/writer method" do
      described_class.send(:define_accessor!, attribute, context)
      instance = dummy_class.new

      expect(instance.setting).to eq("default")
      instance.setting("updated")
      expect(instance.setting).to eq("updated")
    end
  end

  describe ".define_writer!" do
    let(:attribute) do
      Cattri::Attribute.new(
        :mode,
        defined_in: dummy_class,
        default: -> { "auto" },
        expose: :read_write
      )
    end

    it "defines a writer method using 'name='" do
      described_class.send(:define_accessor!, attribute, context)
      described_class.send(:define_writer!, attribute, context)

      instance = dummy_class.new
      instance.mode = "manual"
      expect(instance.mode).to eq("manual")
    end
  end

  describe ".define_predicate!" do
    let(:attribute) do
      Cattri::Attribute.new(
        :active,
        defined_in: dummy_class,
        default: -> {},
        predicate: true,
        expose: :read_write
      )
    end

    it "defines a predicate method returning truthiness" do
      described_class.send(:define_accessor!, attribute, context)
      described_class.send(:define_predicate!, attribute, context)

      instance = dummy_class.new
      expect(instance.active?).to be false
      instance.active("yes")
      expect(instance.active?).to be true
    end
  end

  describe ".memoize_default_value" do
    let(:instance) { dummy_class.new }

    context "non-final attribute" do
      let(:attribute) do
        Cattri::Attribute.new(
          :foo,
          defined_in: dummy_class,
          default: -> { "bar" },
          expose: :read_write
        )
      end

      it "stores and returns the evaluated default" do
        result = described_class.send(:memoize_default_value, instance, attribute)
        expect(result).to eq("bar")
        expect(instance.cattri_variable_get(:foo)).to eq("bar")
      end
    end

    context "final attribute" do
      let(:attribute) do
        Cattri::Attribute.new(
          :immutable,
          defined_in: dummy_class,
          final: true,
          default: -> { "locked" },
          expose: :read
        )
      end

      it "raises if value is not already set" do
        expect do
          described_class.send(:memoize_default_value, instance, attribute)
        end.to raise_error(Cattri::AttributeError, /Final attribute :immutable cannot be written to/)
      end

      it "returns value if already set" do
        instance.cattri_variable_set(:immutable, "preset", final: true)
        result = described_class.send(:memoize_default_value, instance, attribute)

        expect(result).to eq("preset")
      end
    end
  end
end
