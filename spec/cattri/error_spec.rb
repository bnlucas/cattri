# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Error do
  it "raises a Cattri::Error" do
    expect { raise Cattri::Error, "test" }.to raise_error(Cattri::Error, "test")
  end

  describe "Cattri::AttributeDefinedError" do
    let(:attribute) { instance_double(Cattri::Attribute, name: :foo, level: :class) }

    it "raises an error when an attribute is defined more than once" do
      error = Cattri::AttributeDefinedError.new(attribute.level, attribute.name)

      expect(error.message).to eq("Class attribute :foo has already been defined")
    end
  end

  describe "Cattri::AttributeNotDefinedError" do
    it "raises an error when the expected attribute has not been defined" do
      error = Cattri::AttributeNotDefinedError.new(:instance, :attr)

      expect(error.message).to eq("Instance attribute :attr has not been defined")
    end
  end

  describe "Cattri::EmptyAttributeError" do
    it "raises an error when the expected attribute is nil/empty" do
      error = Cattri::EmptyAttributeError.new

      expect(error.message).to eq("Unable to process empty attributes")
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

  describe "Cattri::UnsupportedLevelError" do
    let(:invalid_level) { :invalid_level }

    it "raises an error when an unsupported attribute level is passed" do
      error = Cattri::UnsupportedLevelError.new(invalid_level)

      expect(error.message).to eq("Attribute level :invalid_level is not supported")
    end
  end

  describe "Cattri::AmbiguousBlockError" do
    it "raises an error when an ambiguous block is passed" do
      error = Cattri::AmbiguousBlockError.new

      expect(error.message).to eq("Cannot define multiple attributes with a block")
    end
  end

  describe "Cattri::MissingBlockError" do
    it "raises an error when a missing block is passed" do
      error = Cattri::MissingBlockError.new(:instance, :attr)

      expect(error.message).to eq("A block is required to override the setter for `:attr` (instance attribute)")
    end
  end

  describe "Cattri::FinalizedAttributeError" do
    it "raises an error when attempting to write to or modify a finalized attribute" do
      error = Cattri::FinalizedAttributeError.new(:class, :attr)

      expect(error.message).to eq("Class attribute :attr is marked as final and cannot be modified")
    end
  end

  describe "Cattri::ReadonlyAttributeError" do
    it "raises an error when a setter override is attempted on a readonly attribute" do
      error = Cattri::ReadonlyAttributeError.new(:class, :attr)

      expect(error.message).to eq("Class attribute :attr is marked as readonly and cannot be overwritten")
    end
  end

  describe "Cattri::InvalidAttributeContextError" do
    let(:attribute) { Cattri::Attribute.new(:test_cattr, :class) }

    it "raises an error when an attribute is accessed in the wrong context" do
      error = Cattri::InvalidAttributeContextError.new(:instance, attribute)

      expect(error.message).to eq(
        "Invalid attribute level for :#{attribute.name}. " \
        "Expected :instance, got :#{attribute.level}"
      )
    end
  end

  describe "Cattri::MethodDefinedError" do
    it "raises an error when attempting to redefine a method" do
      klass = Class.new
      error = Cattri::MethodDefinedError.new(:attr, klass)

      expect(error.message).to eq("Method `:attr` already exists on #{klass}. Use `force: true` to override")
    end
  end
end
