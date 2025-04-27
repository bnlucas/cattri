# spec/cattri/errors_spec.rb

require "cattri"

RSpec.describe Cattri::AttributeError do
  let(:test_attribute) { Cattri::Attribute.new(:test_attr, :instance) }
  let(:nested_error) { StandardError.new("Nested failure") }

  describe Cattri::AttributeError do
    it "uses the default message if none provided" do
      error = described_class.new

      expect(error.message).to eq("Attribute error")
      expect(error.attribute).to be_nil
      expect(error.error).to be_nil
    end

    it "wraps an attribute" do
      error = described_class.new(attribute: test_attribute)

      expect(error.attribute).to eq(test_attribute)
      expect(error.message).to eq("Attribute error")
    end

    it "wraps a nested error" do
      error = described_class.new(error: nested_error)

      expect(error.error).to eq(nested_error)
      expect(error.message).to include("Error: Nested failure")
    end
  end

  describe Cattri::AttributeDefinedError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("Instance attribute :test_attr has already been defined")
    end
  end

  describe Cattri::AttributeNotDefinedError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("Instance attribute :test_attr has not been defined")
    end
  end

  describe Cattri::EmptyAttributeError do
    it "uses static default message" do
      error = described_class.new
      expect(error.message).to eq("Unable to process empty attributes")
    end
  end

  describe Cattri::AttributeDefinitionError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("Failed to define method for instance attribute `:test_attr`")
    end
  end

  describe Cattri::UnsupportedAttributeLevelError do
    it "formats message with attribute" do
      error = described_class.new(:unknown_level)
      expect(error.message).to eq("Attribute level :unknown_level is not supported")
    end
  end

  describe Cattri::AmbiguousBlockError do
    it "uses static default message" do
      error = described_class.new
      expect(error.message).to eq("Cannot define multiple attributes with a block")
    end
  end

  describe Cattri::MissingBlockError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("A block is required to override the setter for the instance `:test_attr`")
    end
  end

  describe Cattri::FinalAttributeError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("Instance attribute :test_attr is marked as final and cannot be modified")
    end
  end

  describe Cattri::ReadonlyAttributeError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("Instance attribute :test_attr is marked as readonly and cannot be overwritten")
    end
  end

  describe Cattri::InvalidAttributeError do
    it "uses static default message" do
      error = described_class.new
      expect(error.message).to eq("Invalid attribute provided")
    end
  end

  describe Cattri::InvalidClassAttributeError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("Invalid class attribute provided, received instance attribute `:test_attr`")
    end
  end

  describe Cattri::InvalidInstanceAttributeError do
    it "formats message with attribute" do
      error = described_class.new(attribute: test_attribute)
      expect(error.message).to eq("Invalid instance attribute provided, received class attribute `:test_attr`")
    end
  end

  describe Cattri::MethodDefinedError do
    it "initializes with custom message" do
      error = described_class.new("Method already defined")
      expect(error.message).to eq("Method already defined")
    end
  end
end
