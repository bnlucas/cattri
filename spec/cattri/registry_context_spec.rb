# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::RegistryContext do
  let(:klass) { Class.new }

  before do
    klass.singleton_class.include(Cattri::RegistryContext)
  end

  describe ".attribute_registry" do
    it "returns an AttributeRegistry instance" do
      result = klass.send(:attribute_registry)

      expect(result).to be_a(Cattri::AttributeRegistry)
      expect(result.context.target).to eq(klass)
    end
  end

  describe ".context" do
    it "returns a Context instance" do
      result = klass.send(:context)

      expect(result).to be_a(Cattri::Context)
      expect(result.target).to eq(klass)
    end
  end
end
