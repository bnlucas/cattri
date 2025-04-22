# frozen_string_literal: true

require "spec_helper"
require "cattri/attribute"
require "cattri/context"
require "cattri/attribute_definer"

RSpec.describe Cattri::AttributeDefiner do
  let(:klass) { Class.new }
  let(:context) { Cattri::Context.new(klass) }

  describe ".define_callable_accessor" do
    it "skips instance attributes" do
      attr = Cattri::Attribute.new(:foo, :instance, {}, nil)
      expect { described_class.define_callable_accessor(attr, context) }.not_to(change do
        klass.instance_methods.include?(:foo)
      end)
    end

    it "defines callable reader and no writer when readonly" do
      attr = Cattri::Attribute.new(:foo, :class, { readonly: true, default: 42 }, nil)
      described_class.define_callable_accessor(attr, context)

      expect(klass.foo).to eq(42)
      expect(klass.singleton_class.method_defined?(:foo=)).to eq(false)
    end

    it "defines callable reader and writer when not readonly" do
      attr = Cattri::Attribute.new(:foo, :class, { readonly: false }, nil)
      described_class.define_callable_accessor(attr, context)

      klass.foo = 123
      expect(klass.foo).to eq(123)
    end
  end

  describe ".define_instance_level_reader" do
    it "skips instance attributes" do
      attr = Cattri::Attribute.new(:bar, :instance, {}, nil)
      expect { described_class.define_instance_level_reader(attr, context) }.not_to(change do
        klass.instance_methods.include?(:bar)
      end)
    end

    it "delegates to class-level method for class attribute" do
      attr = Cattri::Attribute.new(:bar, :class, {}, nil)
      klass.define_singleton_method(:bar) { "value" }
      described_class.define_instance_level_reader(attr, context)

      expect(klass.new.bar).to eq("value")
    end
  end

  describe ".define_accessor" do
    it "defines both reader and writer for instance attribute" do
      attr = Cattri::Attribute.new(:baz, :instance, { reader: true, writer: true, default: -> { 1 } }, nil)
      described_class.define_accessor(attr, context)

      instance = klass.new
      expect(instance.baz).to eq(1)

      instance.baz = 99
      expect(instance.baz).to eq(99)
    end

    it "does not define anything for class attribute" do
      attr = Cattri::Attribute.new(:baz, :class, { reader: true, writer: true, default: -> { 1 } }, nil)
      expect { described_class.define_accessor(attr, context) }.not_to(change { klass.instance_methods.include?(:baz) })
    end
  end

  describe ".define_reader" do
    it "defines reader for instance attribute" do
      attr = Cattri::Attribute.new(:r, :instance, { default: -> { "default" } }, nil)
      described_class.define_reader(attr, context)

      expect(klass.new.r).to eq("default")
    end
  end

  describe ".define_writer" do
    it "defines writer for instance attribute" do
      attr = Cattri::Attribute.new(:w, :instance, {}, nil)
      described_class.define_writer(attr, context)
      instance = klass.new
      instance.w = 12

      expect(instance.instance_variable_get(:@w)).to eq(12)
    end
  end
end
