# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::InstanceAttributes do
  subject(:instance) { test_class.new }

  let(:test_class) do
    Class.new do
      extend Cattri::Visibility
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

    it "defines multiple write-only attributes" do
      test_class.instance_attribute :x, :y
      instance = test_class.new

      expect(instance).to respond_to(:x=)
      expect(instance).to respond_to(:y=)
      expect(instance).to respond_to(:x)
      expect(instance).to respond_to(:y)
    end

    it "defines a reader" do
      expect(instance.items).to eq([])
    end

    it "defines a writer" do
      expected = [1, 2, 3]
      instance.items = expected

      expect(instance.items).to eq([1, 2, 3])
    end

    it "defines a predicate method" do
      test_class.iattr :with_predicate, default: "123", predicate: true
      instance = test_class.new

      expect(instance).to respond_to(:with_predicate)
      expect(instance).to respond_to(:with_predicate?)
      expect(instance.with_predicate?).to eq(true)

      instance.with_predicate = nil
      expect(instance.with_predicate?).to eq(false)
    end

    it "raises an AttributeError when a predicate (ends_with?('?')) attribute is defined" do
      expect do
        test_class.iattr :predicate?, default: "123"
      end.to raise_error(Cattri::AttributeError, /names ending in '\?' are not allowed/)
    end

    it "raises an AttributeDefinedError if the attribute is already defined" do
      test_class.iattr :foo, default: 42

      expect do
        test_class.iattr :foo, default: 100
      end.to raise_error(Cattri::AttributeDefinedError, "Instance attribute :foo has already been defined")
    end

    it "raises an AttributeDefinitionError if a method definition fails" do
      test_class = Class.new do
        include Cattri
      end

      allow(Cattri::AttributeDefiner).to receive(:define_accessor).and_raise(StandardError, "method definition failed")

      expect do
        test_class.iattr :bar, default: 10
      end.to raise_error(Cattri::AttributeDefinitionError, /Failed to define method :bar on/)
    end

    it "raises AmbiguousBlockError when using a block with multiple attributes" do
      expect do
        test_class.iattr(:foo, :bar) { |v| v }
      end.to raise_error(Cattri::AmbiguousBlockError, "Cannot define multiple attributes with a block")
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

    it "defines multiple read-only attributes" do
      test_class.iattr_reader :alpha, :beta, default: "readable"

      expect(instance).to respond_to(:alpha)
      expect(instance).to respond_to(:beta)
      expect(instance).not_to respond_to(:alpha=)
      expect(instance).not_to respond_to(:beta=)
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

    it "defines multiple write-only attributes" do
      test_class.iattr_writer :x, :y

      expect(instance).to respond_to(:x=)
      expect(instance).to respond_to(:y=)
      expect(instance).not_to respond_to(:x)
      expect(instance).not_to respond_to(:y)
    end
  end

  describe ".instance_attribute_setter / .iattr_setter" do
    it "replaces the setter for an existing attribute" do
      test_class.instance_attribute_setter(:items) do |val|
        Array(val).map(&:to_sym)
      end

      instance.items = %w[a b c]
      expect(instance.items).to eq(%i[a b c])
    end

    it "raises AttributeNotDefinedError if the attribute is not defined" do
      expect do
        test_class.instance_attribute_setter(:unknown) { |v| v }
      end.to raise_error(Cattri::AttributeNotDefinedError, /Instance attribute :unknown has not been defined/)
    end

    it "raises AttributeDefinitionError if the attribute is readonly" do
      expect do
        test_class.instance_attribute_setter(:readonly) { |v| v }
      end.to raise_error(Cattri::AttributeError, /Cannot define setter for readonly attribute :readonly/)
    end
  end

  describe ".instance_attribute_alias / .iattr_alias" do
    it "defines an alias method" do
      test_class.iattr :original, default: [1, 2, 3]
      test_class.iattr_alias :original_alias, :original
      instance = test_class.new

      expect(instance).to respond_to(:original)
      expect(instance).to respond_to(:original_alias)
      expect(instance.original_alias).to eq(instance.original)
    end

    it "raises AttributeNotDefinedError when the original method is not defined" do
      expect {
        test_class.iattr_alias :alias_method, :unknown
      }.to raise_error(Cattri::AttributeNotDefinedError, /Instance attribute :unknown has not been defined/)
    end
  end

  describe ".instance_attributes / .iattrs" do
    it "returns all defined instance attributes" do
      expect(test_class.instance_attributes).to eq(%i[items readonly secret normalized_symbol])
    end
  end

  describe ".instance_attribute_defined? / .iattr_defined?" do
    it "returns true if instance attribute is defined" do
      expect(test_class.instance_attribute_defined?(:items)).to eq(true)
    end

    it "returns false if instance attribute is not defined" do
      expect(test_class.instance_attribute_defined?(:foo)).to eq(false)
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

  describe "#context" do
    it "returns a Cattri::Context instance" do
      context = instance.class.send(:context)

      expect(context).to be_a(Cattri::Context)
      expect(context.target).to eq(instance.class)
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
  end
end
