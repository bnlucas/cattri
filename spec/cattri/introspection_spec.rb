# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Introspection do
  let(:klass) do
    Class.new do
      include Cattri
      cattri :foo, 123
    end
  end

  let(:subclass) do
    Class.new(klass) do
      include Cattri::Introspection
      cattri :bar, "bar"
    end
  end

  before do
    klass.include(Cattri::Introspection)
  end

  describe ".attribute_defined?" do
    it "returns true for defined attributes" do
      expect(klass.attribute_defined?(:foo)).to be true
    end

    it "returns false for unknown attributes" do
      expect(klass.attribute_defined?(:missing)).to be false
    end
  end

  describe ".attribute" do
    it "returns the attribute definition" do
      attr = klass.attribute(:foo)
      expect(attr).to be_a(Cattri::Attribute)
      expect(attr.name).to eq(:foo)
    end

    it "returns nil for unknown attributes" do
      expect(klass.attribute(:missing)).to be_nil
    end
  end

  describe ".attributes" do
    it "lists local attributes by default" do
      expect(subclass.attributes).to eq([:bar])
    end

    it "includes inherited attributes when requested" do
      expect(subclass.attributes(with_ancestors: true)).to match_array(%i[foo bar])
    end
  end

  describe ".attribute_definitions" do
    it "returns a hash of defined attributes" do
      defs = subclass.attribute_definitions
      expect(defs).to be_a(Hash)
      expect(defs).to have_key(:bar)
      expect(defs[:bar]).to be_a(Cattri::Attribute)
    end

    it "includes ancestors if requested" do
      defs = subclass.attribute_definitions(with_ancestors: true)
      expect(defs).to have_key(:foo)
      expect(defs[:foo]).to be_a(Cattri::Attribute)
    end
  end

  describe ".attribute_methods" do
    it "returns a hash of methods per attribute" do
      methods = subclass.attribute_methods
      expect(methods).to be_a(Hash)
      expect(methods.keys).to include(:bar)
      expect(methods[:bar]).to include(:bar)
    end
  end

  describe ".attribute_source" do
    it "returns the class where the attribute was originally defined" do
      expect(subclass.attribute_source(:foo)).to eq(klass)
      expect(subclass.attribute_source(:bar)).to eq(subclass)
    end

    it "returns nil for unknown attributes" do
      expect(subclass.attribute_source(:missing)).to be_nil
    end
  end
end
