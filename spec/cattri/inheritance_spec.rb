# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Inheritance do
  let(:base_class) do
    Class.new.tap do |klass|
      klass.include(Cattri::ContextRegistry)
      klass.singleton_class.include(Cattri::ContextRegistry)

      klass.attr_reader :inherited_called_with

      def klass.inherited(subclass)
        @inherited_called_with = subclass
      end

      def klass.inherited_called_with # rubocop:disable Style/TrivialAccessors
        @inherited_called_with
      end
    end
  end

  before do
    allow(Cattri::Context).to receive(:new).and_call_original
    allow_any_instance_of(Cattri::AttributeRegistry).to receive(:copy_attributes_to)
  end

  describe ".install" do
    it "preserves and calls existing inherited method" do
      Cattri::Inheritance.install(base_class)

      subclass = Class.new(base_class) # triggers inherited hook

      expect(base_class.inherited_called_with).to eq(subclass)
    end

    it "initializes a Cattri::Context for the subclass" do
      Cattri::Inheritance.install(base_class)

      expect(Cattri::Context).to receive(:new) do |actual_subclass|
        expect(actual_subclass.superclass).to eq(base_class)
      end

      Class.new(base_class)
    end

    it "invokes copy_attributes_to with the subclass context" do
      context = instance_double(Cattri::Context)
      allow(Cattri::Context).to receive(:new).and_return(context)

      registry = instance_double(Cattri::AttributeRegistry)
      allow(base_class).to receive(:attribute_registry).and_return(registry)

      expect(registry).to receive(:copy_attributes_to).with(context)

      Cattri::Inheritance.install(base_class)
      Class.new(base_class)
    end
  end
end
