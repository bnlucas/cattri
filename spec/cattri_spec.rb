# frozen_string_literal: true

require "spec_helper"
require "cattri"

RSpec.describe Cattri do
  let(:klass) do
    Class.new do
      include Cattri

      cattr :enabled, default: true
      iattr :name, default: "anonymous"
    end
  end

  describe "included behavior" do
    it "adds cattr and iattr support" do
      expect(klass.enabled).to eq(true)
      expect(klass.new.name).to eq("anonymous")
    end

    it "persists values set on class and instance" do
      klass.enabled(false)
      instance = klass.new
      instance.name = "overridden"

      expect(klass.enabled).to eq(false)
      expect(instance.name).to eq("overridden")
    end

    it "does not include introspection by default" do
      expect(klass.included_modules).not_to include(Cattri::Introspection)
      expect(klass.singleton_class.included_modules).not_to include(Cattri::Introspection)
    end
  end

  describe "inheritance behavior" do
    let!(:parent_instance) do
      klass.enabled(false)
      obj = klass.new
      obj.name = "parent"
      obj
    end

    let(:subclass) do
      klass.enabled(false)
      Class.new(klass)
    end

    it "inherits cattr state (class-level attributes)" do
      expect(subclass.enabled).to eq(false)
    end

    it "inherits iattr default value (instance-level attributes)" do
      instance = subclass.new
      expect(instance.name).to eq("anonymous")
    end

    context "when inherited is overridden" do
      let(:overridden_inherited_class) do
        Class.new(klass) do
          def self.inherited(_subclass)
            puts "inherited method overridden"
          end
        end
      end

      let(:subclass_with_overridden_inherited) { Class.new(overridden_inherited_class) }

      it "does not raise an error when `super` is not called" do
        expect { subclass_with_overridden_inherited.new }.not_to raise_error
      end
    end

    context "when `super` is removed dynamically" do
      let(:parent_class_with_removed_inherited) do
        Class.new do
          include Cattri
        end
      end

      let(:subclass_with_removed_inherited) { Class.new(parent_class_with_removed_inherited) }

      it "does not raise an error when `super` is removed" do
        parent_class_with_removed_inherited.singleton_class.send(:remove_method, :inherited)
        expect { subclass_with_removed_inherited.new }.not_to raise_error
      end
    end
  end

  describe "copy_attributes_to" do
    it "copies all attribute metadata and state to subclass" do
      subclass = Class.new do
        include Cattri
      end

      Cattri.send(:copy_attributes_to, klass, subclass, :class)

      expect(subclass.private_methods(false)).to include(:attribute_registry)
      expect(subclass.private_methods(false)).to include(:context)
      expect(subclass.class_attributes).to eq(klass.class_attributes)
    end
  end

  describe "#duplicate_value" do
    let(:origin_class) do
      Class.new do
        include Cattri::ClassAttributes
      end
    end

    let(:attribute) { instance_double(Cattri::Attribute, ivar: :@foo) }

    context "when the value is duplicable" do
      it "duplicates the value" do
        # Prepare a mock that responds to `dup` method
        allow(origin_class).to receive(:instance_variable_get).with(:@foo).and_return("test_value")

        result = Cattri.send(:duplicate_value, origin_class, attribute)

        expect(result).to eq("test_value")
        expect(result).not_to be("test_value") # Ensure the object was duplicated
      end
    end

    it "rescues from errors and returns the original value" do
      invalid_value = double("invalid_value")

      allow(invalid_value).to receive(:dup).and_raise(TypeError, "Cannot duplicate object")
      allow(origin_class).to receive(:instance_variable_get).with(:@foo).and_return(invalid_value)

      result = Cattri.send(:duplicate_value, origin_class, attribute)

      expect(result).to eq(invalid_value)
    end

    context "when the value cannot be duplicated (TypeError, FrozenError, etc.)" do
      it "returns the original value" do
        allow(origin_class).to receive(:instance_variable_get).with(:@foo).and_return(Object.new)

        result = Cattri.send(:duplicate_value, origin_class, attribute)

        expect(result).to be_a(Object)
      end
    end

    context "when duplication fails for another reason" do
      it "raises an AttributeError" do
        allow(origin_class).to receive(:instance_variable_get).with(:@foo).and_raise(StandardError.new("dup failed"))

        expect do
          Cattri.send(:duplicate_value, origin_class, attribute)
        end.to raise_error(Cattri::AttributeError, /Failed to duplicate value for attribute/)
      end
    end
  end
end
