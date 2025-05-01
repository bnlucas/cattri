# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::ContextRegistry do
  let(:klass) do
    Class.new do
      include Cattri::ContextRegistry
      public :context, :attribute_registry
    end
  end

  subject(:instance) { klass.new }

  describe "#context" do
    it "returns a Cattri::Context wrapping self" do
      result = instance.context
      expect(result).to be_a(Cattri::Context)
      expect(result.target).to eq(instance)
    end

    it "memoizes the context" do
      expect(instance.context).to equal(instance.context)
    end
  end

  describe "#attribute_registry" do
    it "returns a Cattri::AttributeRegistry instance" do
      result = instance.attribute_registry
      expect(result).to be_a(Cattri::AttributeRegistry)
    end

    it "is initialized with the context" do
      expect(Cattri::AttributeRegistry).to receive(:new)
        .with(instance.context)
        .and_call_original

      instance.attribute_registry
    end

    it "memoizes the registry" do
      expect(instance.attribute_registry).to equal(instance.attribute_registry)
    end
  end
end
