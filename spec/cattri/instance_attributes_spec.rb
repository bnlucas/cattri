# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::InstanceAttributes do
  subject(:instance) { test_class.new }

  let(:test_class) do
    Class.new do
      include Cattri::InstanceAttributes
      include Cattri::Introspection

      iattr :items, default: []
      iattr_reader :readonly, default: true
      iattr_writer :secret

      iattr :normalized_symbol, default: :symbol do |value|
        value.to_s.downcase.to_sym
      end
    end
  end

  describe ".instance_attribute / .iattr" do
    it "defines an instance-level attribute" do
      expect(instance).to respond_to(:items)
    end

    it "defines a reader" do
      expect(instance.items).to eq([])
    end

    it "defines a writer" do
      expected = [1, 2, 3]
      instance.items = expected

      expect(instance.items).to eq([1, 2, 3])
    end
  end

  describe ".instance_attribute_reader / .iattr_reader" do
    it "defines a reader" do
      expect(instance).to respond_to(:readonly)
    end

    it "does not define a writer" do
      expect(instance).not_to respond_to(:readonly=)
    end

    it "does not allow setting a readonly attribute" do
      expect { instance.readonly = "fail" }.to raise_error(NoMethodError)
    end
  end

  describe ".instance_attribute_writer / .iattr_writer" do
    it "do not defines a reader" do
      expect(instance).not_to respond_to(:secret)
    end

    it "defines a writer" do
      expect(instance).to respond_to(:secret=)
    end

    it "does not allow getting a write-only attribute" do
      expect { instance.secret }.to raise_error(NoMethodError)
    end
  end

  describe ".instance_attributes / .iattrs" do
    it "returns all defined instance attributes" do
      expect(test_class.instance_attributes).to eq(%i[items readonly secret normalized_symbol])
    end
  end

  describe ".instance_attribute_defined? / .iattr_defined?" do
    it "returns true if instance attribute is defined" do
      expect(test_class.instance_attribute_defined?(:items)).to be(true)
    end

    it "returns false if instance attribute is not defined" do
      expect(test_class.instance_attribute_defined?(:foo)).to be(false)
    end
  end

  describe ".instance_attribute_definition / .iattr_definition" do
    it "returns an attribute definition for a defined attribute" do
      definition = test_class.instance_attribute_definition(:normalized_symbol)

      expect(definition).not_to be_nil
      expect(definition).to include(ivar: :@normalized_symbol, reader: true, writer: true)
      expect(definition[:default]).to be_a(Proc)
      expect(definition[:setter]).to be_a(Proc)

      expect(definition[:default].call).to eq(:symbol)
      expect(definition[:setter].call("TESTING")).to eq(:testing)
    end
  end

  describe ".reset_instance_attributes! / .reset_iattrs!" do
    it "resets all class attributes" do
      default_values = instance.snapshot_instance_attributes

      instance.items = [1, 2, 3]
      instance.secret = "secret"
      instance.normalized_symbol = :testing

      set_values = instance.snapshot_instance_attributes
      expect(default_values).not_to eq(set_values)

      instance.reset_instance_attributes!
      reset_values = instance.snapshot_instance_attributes

      expect(reset_values).to eq(default_values)
    end
  end

  describe ".reset_instance_attribute! / .reset_iattr!" do
    before do
      allow(instance).to receive(:reset_attributes).and_call_original
    end

    it "resets a given attribute" do
      default_values = instance.snapshot_instance_attributes

      instance.items = [1, 2, 3]
      instance.secret = "secret"

      set_values = instance.snapshot_instance_attributes
      expect(default_values).not_to eq(set_values)

      instance.reset_instance_attribute!(:items)
      expect(instance.items).to eq([])
      expect(instance.instance_variable_get(:@secret)).to eq("secret")
    end

    it "does nothing for an unknown attribute" do
      instance.reset_instance_attribute!(:foo)

      expect(instance).not_to have_received(:reset_attributes)
    end
  end

  describe "aliases" do
    [
      %i[iattr instance_attribute],
      %i[iattr_accessor instance_attribute],
      %i[iattr_reader instance_attribute_reader],
      %i[iattr_writer instance_attribute_writer],
      %i[iattrs instance_attributes],
      %i[iattr_defined? instance_attribute_defined?],
      %i[iattr_definition instance_attribute_definition]
    ].each do |alias_name, method_name|
      it "aliases .#{alias_name} to .#{method_name}" do
        expect(test_class.method(alias_name)).to eq(test_class.method(method_name))
      end
    end

    [
      %i[reset_iattrs! reset_instance_attributes!],
      %i[reset_iattr! reset_instance_attribute!]
    ].each do |alias_name, method_name|
      it "aliases ##{alias_name} to ##{method_name}" do
        expect(instance.method(alias_name)).to eq(instance.method(method_name))
      end
    end
  end
end
