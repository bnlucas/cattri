# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::ClassAttributes do
  subject { test_class }

  let(:test_class) do
    Class.new do
      extend Cattri::ClassAttributes
      include Cattri::Introspection

      cattr :items, default: []
      cattr :map, default: {}
      cattr_reader :readonly, default: "static"
      cattr :no_instance_access, default: true, instance_reader: false

      cattr :normalized_symbol, default: :symbol do |value|
        value.to_s.downcase.to_sym
      end
    end
  end

  before do
    allow(test_class).to receive(:instance_variable_set).and_call_original
  end

  describe ".class_attribute / .cattr" do
    it "defines a class-level attribute" do
      expect(subject).to respond_to(:items)
    end

    it "defines a reader" do
      expect(subject.items).to eq([])
    end

    it "defines a writer" do
      expected = [1, 2, 3]
      subject.items = expected

      expect(subject.items).to eq([1, 2, 3])
    end

    it "supports callable setter access" do
      expected = %i[a b c]
      subject.items :a, :b, :c

      expect(subject.items).to eq(expected)
    end

    it "sets value via callable setter" do
      expect { subject.items(:foo, :bar) }.to change { subject.items }.from([]).to(%i[foo bar])
    end

    it "defines an instance-level reader" do
      subject.items :a, :b, :c
      instance = subject.new

      expect(instance).to respond_to(:items)
      expect(instance.items).to eq(%i[a b c])
    end

    it "does not define an instance-level reader with instance_reader: false" do
      instance = subject.new

      expect(subject).to respond_to(:no_instance_access)
      expect(instance).not_to respond_to(:no_instance_access)
    end

    it "raises an error on duplicate attribute names" do
      expect do
        Class.new do
          extend Cattri::ClassAttributes
          cattr :items, default: []
          cattr :items, default: []
        end
      end.to raise_error(Cattri::Error, /Class attribute `items` already defined/)
    end
  end

  describe ".class_attribute_reader / .cattr_reader" do
    it "defines a reader" do
      expect(subject).to respond_to(:readonly)
    end

    it "does not define a writer" do
      expect(subject).not_to respond_to(:readonly=)
    end

    it "does not allow setting a readonly attribute" do
      expect { subject.readonly = "fail" }.to raise_error(NoMethodError)
    end

    it "defines a readonly accessor" do
      subject.readonly "readonly"

      expect(subject.readonly).to eq("static")
      expect(subject).not_to have_received(:instance_variable_set).with(:@readonly, "readonly")
    end
  end

  describe ".class_attributes / .cattrs" do
    it "returns all defined class attributes" do
      expect(subject.class_attributes).to eq(%i[items map readonly no_instance_access normalized_symbol])
    end
  end

  describe ".class_attribute_defined? / .cattr_defined?" do
    it "returns true if class attribute is defined" do
      expect(subject.class_attribute_defined?(:items)).to be(true)
    end

    it "returns false if class attribute is not defined" do
      expect(subject.class_attribute_defined?(:foo)).to be(false)
    end
  end

  describe ".class_attribute_definition / .cattr_definition" do
    it "returns an attribute definition for a defined attribute" do
      definition = subject.class_attribute_definition(:normalized_symbol)

      expect(definition).not_to be_nil
      expect(definition).to include(ivar: :@normalized_symbol, readonly: false)
      expect(definition[:default]).to be_a(Proc)
      expect(definition[:setter]).to be_a(Proc)

      expect(definition[:default].call).to eq(:symbol)
      expect(definition[:setter].call("TESTING")).to eq(:testing)
    end
  end

  describe ".reset_class_attributes! / .reset_cattrs!" do
    it "resets all class attributes" do
      default_values = subject.snapshot_class_attributes

      subject.items = [1, 2, 3]
      subject.map = { a: 1, b: 2, c: 3 }
      subject.normalized_symbol = :testing

      set_values = subject.snapshot_class_attributes
      expect(default_values).not_to eq(set_values)

      subject.reset_class_attributes!
      reset_values = subject.snapshot_class_attributes

      expect(reset_values).to eq(default_values)
    end
  end

  describe ".reset_class_attribute! / .reset_cattr!" do
    before do
      allow(subject).to receive(:reset_attributes).and_call_original
    end

    it "resets a given attribute" do
      default_values = subject.snapshot_class_attributes

      subject.items = [1, 2, 3]
      subject.map = { a: 1, b: 2, c: 3 }

      set_values = subject.class_attributes.map { |k| subject.send(k) }
      expect(default_values).not_to eq(set_values)

      subject.reset_class_attribute!(:items)
      expect(subject.items).to eq([])
      expect(subject.map).to eq({ a: 1, b: 2, c: 3 })
    end

    it "does nothing for an unknown attribute" do
      subject.reset_class_attribute!(:foo)

      expect(subject).not_to have_received(:reset_attributes)
    end
  end

  describe "inheritance behavior" do
    let(:parent_class) do
      Class.new do
        extend Cattri::ClassAttributes

        cattr :items, default: []
      end
    end

    let(:child_class_a) { Class.new(parent_class) }
    let(:child_class_b) { Class.new(parent_class) }

    it "gives subclasses an isolated copy of class attributes" do
      parent_class.items << :a
      child_class_a.items << :b

      expect(parent_class.items).to eq([:a])
      expect(child_class_a.items).to eq(%i[a b])
      expect(child_class_b.items).to eq([:a])
    end
  end

  describe "aliases" do
    [
      %i[cattr class_attribute],
      %i[cattr_accessor class_attribute],
      %i[cattr_reader class_attribute_reader],
      %i[cattrs class_attributes],
      %i[cattr_defined? class_attribute_defined?],
      %i[cattr_definition class_attribute_definition],
      %i[reset_cattrs! reset_class_attributes!],
      %i[reset_cattr! reset_class_attribute!]
    ].each do |alias_name, method_name|
      it "defines the alias #{alias_name} to #{method_name}" do
        expect(subject.method(alias_name)).to eq(subject.method(method_name))
      end
    end
  end
end
