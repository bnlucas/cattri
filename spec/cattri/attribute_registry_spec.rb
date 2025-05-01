# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::AttributeRegistry do
  let(:parent_klass) do
    Class.new do
      include Cattri
    end
  end

  let(:klass) do
    Class.new(parent_klass) do
      include Cattri
    end
  end

  let(:context) { Cattri::Context.new(klass) }
  let(:defer) { false }

  subject(:registry) { Cattri::AttributeRegistry.new(context) }

  before do
    allow(context).to receive(:defer_definitions?).and_return(defer)
  end

  describe "#initialize" do
    it "instantiates an AttributeRegistry instance with context" do
      expect(registry).to be_a(Cattri::AttributeRegistry)
      expect(registry.context).to eq(context)
    end
  end

  describe "#registered_attributes" do
    it "returns a Hash" do
      expect(context.send(:__cattri_defined_methods)).to be_a(Hash)
    end

    it "returns the defined attributes" do
      registry.define_attribute(:enabled, true)

      expect(registry.registered_attributes).to be_a(Hash)
      expect(registry.registered_attributes[:enabled]).to be_a(Cattri::Attribute)
    end
  end

  describe "#defined_attributes" do
    let(:parent_attribute) { Cattri::Attribute.new(:parent, defined_in: context.target) }
    let(:attribute) { Cattri::Attribute.new(:enabled, defined_in: context.target) }

    before do
      parent_klass.send(:attribute_registry)
                  .instance_variable_set(
                    :@__cattri_registered_attributes,
                    { parent_attribute.name => parent_attribute }
                  )

      registry.instance_variable_set(:@__cattri_registered_attributes, { attribute.name => attribute })
    end

    it "returns only instance-level attributes by default" do
      expect(registry.defined_attributes.values).to eq([attribute])
    end

    it "returns all attributes, instance- and ancestor-level, when setting with_ancestors: true" do
      expect(registry.defined_attributes(with_ancestors: true).values).to eq([parent_attribute, attribute])
    end
  end

  describe "#fetch_attribute" do
    it "fetches a defined attribute" do
      registry.define_attribute(:enabled, true)
      attribute = registry.fetch_attribute(:enabled)

      expect(attribute).to be_a(Cattri::Attribute)
      expect(attribute.name).to eq(:enabled)
      expect(attribute.defined_in).to eq(context.target)
    end

    it "returns nil on undefined attributes" do
      attribute = registry.fetch_attribute(:undefined)
      expect(attribute).to be_nil
    end
  end

  describe "#fetch_attribute!" do
    it "fetches a defined attribute" do
      registry.define_attribute(:enabled, true)
      attribute = registry.fetch_attribute!(:enabled)

      expect(attribute).to be_a(Cattri::Attribute)
      expect(attribute.name).to eq(:enabled)
      expect(attribute.defined_in).to eq(context.target)
    end

    it "raises an error on undefined attributes" do
      expect { registry.fetch_attribute!(:undefined) }
        .to raise_error(Cattri::AttributeError, "Attribute :undefined has not been defined")
    end
  end

  describe "#define_attribute" do
    it "defines an attribute" do
      registry.define_attribute(:enabled, true)
      attribute = registry.fetch_attribute(:enabled)

      expect(attribute).to be_a(Cattri::Attribute)
      expect(attribute.name).to eq(:enabled)
      expect(attribute.defined_in).to eq(context.target)
    end

    it "raises an error on duplicate attribute definitions" do
      registry.define_attribute(:enabled, true)

      expect { registry.define_attribute(:enabled, true) }
        .to raise_error(Cattri::AttributeError, "Attribute :enabled has already been defined")
    end
  end

  describe "#copy_attributes_to" do
    let(:target_klass) do
      Class.new do
        include Cattri
      end
    end

    let!(:target_registry) { target_klass.send(:attribute_registry) }
    let(:target_context) { Cattri::Context.new(target_klass) }

    it "copies final class attributes and sets their values" do
      registry.define_attribute(:enabled, "yes", scope: :class, final: true)
      registry.context.target.cattri_variable_set(:@enabled, "yes")

      registry.copy_attributes_to(target_context)

      expect(target_klass.cattri_variable_get(:@enabled)).to eq("yes")
      expect(target_registry.fetch_attribute(:enabled)).to be_a(Cattri::Attribute)
    end

    it "skips non-final or instance-level attributes" do
      registry.define_attribute(:skipped1, "val", scope: :instance, final: true)
      registry.define_attribute(:skipped2, "val", scope: :class, final: false)

      expect do
        registry.copy_attributes_to(target_context)
      end.not_to(change { target_klass.send(:attribute_registry).defined_attributes })
    end

    it "restores original context after copying" do
      original_context = registry.context
      registry.copy_attributes_to(target_context)

      expect(registry.context).to equal(original_context)
    end
  end

  describe "#validate_unique!" do
    context "when no attributes are registered" do
      it "returns without raising" do
        expect { registry.send(:validate_unique!, :enabled) }.not_to raise_error
      end
    end

    context "when attribute exists in @__cattri_registered_attributes" do
      before do
        registry.define_attribute(:enabled, true)
      end

      it "raises an error on duplicate attribute definitions" do
        expect { registry.send(:validate_unique!, :enabled) }
          .to raise_error(Cattri::AttributeError, "Attribute :enabled has already been defined")
      end
    end

    context "when @__cattri_registered_attributes is defined but attribute does not exist" do
      before do
        registry.define_attribute(:existing, true)
      end

      it "does not raise error for a different attribute" do
        expect { registry.send(:validate_unique!, :something_else) }.not_to raise_error
      end
    end
  end

  describe "#register_attribute" do
    let(:attribute) { Cattri::Attribute.new(:enabled, defined_in: context.target) }

    before do
      allow(registry).to receive(:defer_definition).and_return(nil)
      allow(registry).to receive(:apply_definition!).and_return(nil)
    end

    it "registers the attribute in __defined_attributes" do
      expect(registry.defined_attributes).to be_empty

      registry.send(:register_attribute, attribute)

      expect(registry.fetch_attribute(attribute.name)).to eq(attribute)
    end

    context "when attributes are not deferred" do
      it "applies the attribute definition" do
        registry.send(:register_attribute, attribute)

        expect(registry).not_to have_received(:defer_definition)
        expect(registry).to have_received(:apply_definition!).with(attribute)
      end
    end

    context "when attributes are deferred" do
      let(:defer) { true }

      it "defers the attribute definition" do
        registry.send(:register_attribute, attribute)

        expect(registry).to have_received(:defer_definition).with(attribute)
        expect(registry).not_to have_received(:apply_definition!)
      end
    end
  end

  describe "#defer_definition" do
    let(:attribute) { Cattri::Attribute.new(:enabled, defined_in: context.target) }

    before do
      allow(context).to receive(:ensure_deferred_support!)
      allow(context.target).to receive(:defer_attribute)
    end

    it "defers the attribute definition to context" do
      registry.send(:defer_definition, attribute)

      expect(context).to have_received(:ensure_deferred_support!)
      expect(context.target).to have_received(:defer_attribute).with(attribute)
    end
  end

  describe "#apply_definition!" do
    let(:attribute) { Cattri::Attribute.new(:enabled, defined_in: context.target) }

    it "calls Cattri::AttributeCompiler.define_accessor" do
      allow(Cattri::AttributeCompiler).to receive(:define_accessor)

      registry.send(:apply_definition!, attribute)

      expect(Cattri::AttributeCompiler).to have_received(:define_accessor).with(attribute, context)
    end

    it "raises a Cattri::AttributeError when definition fails" do
      allow(Cattri::AttributeCompiler).to receive(:define_accessor).and_raise(TypeError, "boom")

      expect { registry.send(:apply_definition!, attribute) }
        .to raise_error(Cattri::AttributeError, "Attribute #{attribute.name} could not be defined. Error: boom")
    end
  end
end
