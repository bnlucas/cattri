# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Error do
  it "raises a Cattri::Error" do
    expect { raise Cattri::Error, "test" }.to raise_error(Cattri::Error, "test")
  end

  describe "Cattri::AttributeDefinedError" do
    let(:attribute) { instance_double(Cattri::Attribute, name: :foo, type: :class) }

    it "raises an error when an attribute is defined more than once" do
      error = Cattri::AttributeDefinedError.new(attribute)

      expect(error.message).to eq("Class attribute :foo has already been defined")
    end
  end

  describe "Cattri::AttributeDefinitionError" do
    let(:target) { double("TargetClass") }
    let(:attribute) { instance_double(Cattri::Attribute, name: :foo) }
    let(:original_error) { StandardError.new("method definition failed") }

    it "raises an error when defining an attribute method fails" do
      error = Cattri::AttributeDefinitionError.new(target, attribute, original_error)

      expect(error.message).to eq("Failed to define method :foo on #{target}. Error: method definition failed")
      expect(error.backtrace).to eq(original_error.backtrace)
    end
  end

  describe "Cattri::UnsupportedTypeError" do
    let(:invalid_type) { :invalid_type }

    it "raises an error when an unsupported attribute type is passed" do
      error = Cattri::UnsupportedTypeError.new(invalid_type)

      expect(error.message).to eq("Attribute type :invalid_type is not supported")
    end
  end

  describe "Cattri::AmbiguousBlockError" do
    it "raises an error when an ambiguous block is passed" do
      error = Cattri::AmbiguousBlockError.new

      expect(error.message).to eq("Cannot define multiple attributes with a block")
    end
  end
end
