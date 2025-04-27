# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Introspection do
  let(:klass) do
    Class.new do
      include Cattri

      with_cattri_introspection
    end
  end

  describe ".class_attribute_defined? / .cattr_defined?" do
    before { klass.cattr :class_attr }

    it "returns true when the class attribute has been defined" do
      expect(klass.class_attribute_defined?(:class_attr)).to be(true)
    end

    it "returns false when the class attribute has been not defined" do
      expect(klass.class_attribute_defined?(:unknown)).to be(false)
    end
  end

  describe ".class_attribute_definition / .cattr_definition" do
    before { klass.cattr :class_attr }

    it "returns the attribute definition" do
      definition = klass.class_attribute_definition(:class_attr)

      expect(definition).to be_a(Cattri::Attribute)
      expect(definition.name).to eq(:class_attr)
    end
  end

  describe ".instance_attribute_defined? / .instance_defined?" do
    before { klass.iattr :instance_attr }

    it "returns true when the instance attribute has been defined" do
      expect(klass.instance_attribute_defined?(:instance_attr)).to be(true)
    end

    it "returns false when the instance attribute has been not defined" do
      expect(klass.instance_attribute_defined?(:unknown)).to be(false)
    end
  end

  describe ".instance_attribute_definition / .instance_definition" do
    before { klass.iattr :instance_attr }

    it "returns the attribute definition" do
      definition = klass.instance_attribute_definition(:instance_attr)

      expect(definition).to be_a(Cattri::Attribute)
      expect(definition.name).to eq(:instance_attr)
    end
  end

  describe ".snapshot_class_attributes / snapshot_cattrs" do
    before { klass.cattr :class_attr, default: "default" }

    it "returns an empty hash when Cattri::ClassAttributes is not extended" do
      allow(klass).to receive(:respond_to?).with(:class_attributes).and_return(false)

      expect(klass.snapshot_class_attributes).to eq({})
    end

    it "returns the current snapshot of class attribute values" do
      expect(klass.snapshot_class_attributes).to eq({ class_attr: "default" })

      klass.class_attr = "updated"
      expect(klass.snapshot_class_attributes).to eq({ class_attr: "updated" })
    end
  end

  describe ".snapshot_class_attributes / .snapshot_cattrs" do
    before { klass.cattr :class_attr, default: "default" }

    it "returns an empty hash when Cattri::ClassAttributes is not extended" do
      allow(klass).to receive(:respond_to?).with(:class_attributes).and_return(false)

      expect(klass.snapshot_class_attributes).to eq({})
    end

    it "returns the current snapshot of class attribute values" do
      expect(klass.snapshot_class_attributes).to eq({ class_attr: "default" })

      klass.class_attr = "updated"
      expect(klass.snapshot_class_attributes).to eq({ class_attr: "updated" })
    end
  end

  describe "#snapshot_instance_attributes / #snapshot_iattrs" do
    subject(:instance) { klass.new }

    before { klass.iattr :instance_attr, default: "default" }

    it "returns an empty hash when Cattri::ClassAttributes is not extended" do
      allow(klass).to receive(:respond_to?).with(:instance_attributes).and_return(false)

      expect(instance.snapshot_instance_attributes).to eq({})
    end

    it "returns the current snapshot of class attribute values" do
      expect(instance.snapshot_instance_attributes).to eq({ instance_attr: "default" })

      instance.instance_attr = "updated"
      expect(instance.snapshot_instance_attributes).to eq({ instance_attr: "updated" })
    end

    it "returns the stored ivar for write-only attributes" do
      klass.iattr_writer :write_only_attr, default: "default"
      instance = klass.new

      expect(instance.snapshot_instance_attributes).to include(write_only_attr: "default")

      instance.write_only_attr = "updated"
      expect(instance.snapshot_instance_attributes).to include(write_only_attr: "updated")
    end
  end

  describe "class method aliases" do
    [
      %i[cattr_defined? class_attribute_defined?],
      %i[cattr_definition class_attribute_definition],
      %i[iattr_defined? instance_attribute_defined?],
      %i[iattr_definition instance_attribute_definition],
      %i[snapshot_cattrs snapshot_class_attributes]
    ].each do |alias_name, method_name|
      it "defines the alias #{alias_name} to #{method_name}" do
        expect(klass.method(alias_name)).to eq(klass.method(method_name))
      end
    end
  end

  describe "instance method aliases" do
    subject(:instance) { klass.new }

    [
      %i[snapshot_iattrs snapshot_instance_attributes]
    ].each do |alias_name, method_name|
      it "defines the alias #{alias_name} to #{method_name}" do
        expect(instance.method(alias_name)).to eq(instance.method(method_name))
      end
    end
  end
end
