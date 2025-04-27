# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::AttributeRegistry do
  let(:ancestor) do
    Class.new do
      include Cattri

      iattr :ancestor_attr
    end
  end

  let(:ancestor_context) { ancestor.send(:context) }
  let(:ancestor_registry) { ancestor.send(:attribute_registry) }

  let(:klass) { Class.new(ancestor) }

  let(:context) { Cattri::Context.new(klass) }
  let(:class_attribute) { Cattri::Attribute.new(:test_cattr, :class) }
  let(:instance_attribute) { Cattri::Attribute.new(:test_iattr, :instance) }
  let(:defined_attributes) do
    {
      class: { class_attribute.name => class_attribute },
      instance: { instance_attribute.name => instance_attribute }
    }
  end

  subject(:registry) { described_class.new(context) }

  describe "#context" do
    it "returns the context provided during instantiation" do
      expect(registry.context).to eq(context)
    end
  end

  describe "#defined_attributes" do
    before do
      registry.instance_variable_set(:@__defined_attributes, defined_attributes)
    end

    it "returns the defined attributes" do
      class_attributes = registry.defined_attributes(:class)

      expect(class_attributes.values).to eq([class_attribute])
      expect(class_attributes.frozen?).to be(true)
    end

    it "returns the defined attributes, including those on any ancestors with with_ancestors: true" do
      instance_attributes = registry.defined_attributes(:instance, with_ancestors: true)
      ancestor_attributes = ancestor_registry.defined_attributes(:instance)

      expect(instance_attributes.values).to match_array([instance_attribute] + ancestor_attributes.values)
      expect(instance_attributes.frozen?).to be(true)
    end
  end

  describe "#fetch_attribute" do
    before do
      registry.instance_variable_set(:@__defined_attributes, defined_attributes)
    end

    it "returns a defined class attribute" do
      result = registry.fetch_attribute(:class, class_attribute.name)
      expect(result).to eq(class_attribute)
    end

    it "returns a defined instance attribute" do
      result = registry.fetch_attribute(:instance, instance_attribute.name)
      expect(result).to eq(instance_attribute)
    end

    it "returns nil for an undefined attribute" do
      result = registry.fetch_attribute(:class, :unknown)
      expect(result).to be_nil
    end
  end

  describe "#fetch_attribute!" do
    before do
      registry.instance_variable_set(:@__defined_attributes, defined_attributes)
    end

    it "returns a defined class attribute" do
      result = registry.fetch_attribute!(:class, class_attribute.name)
      expect(result).to eq(class_attribute)
    end

    it "returns a defined instance attribute" do
      result = registry.fetch_attribute!(:instance, instance_attribute.name)
      expect(result).to eq(instance_attribute)
    end

    it "raises an error for an undefined attribute" do
      expect do
        registry.fetch_attribute!(:class, :unknown)
      end.to raise_error(Cattri::AttributeNotDefinedError, /Class attribute :unknown/)
    end
  end

  describe "#define_class_attributes" do
    it "defines a single class attribute" do
      registry.define_class_attributes([:class_attr], options: { readonly: true }, block: lambda(&:to_s))

      result = registry.fetch_attribute(:class, :class_attr)

      expect(result).to be_a(Cattri::Attribute)
      expect(result.to_h).to include(name: :class_attr, level: :class, readonly: true)
    end

    it "defines multiple class attribute" do
      registry.define_class_attributes(%i[class_attr_a class_attr_b], options: { readonly: true })

      result = registry.defined_attributes(:class)

      expect(result.size).to eq(2)
      expect(result.keys).to eq(%i[class_attr_a class_attr_b])
    end
  end

  describe "#define_instance_attributes" do
    it "defines a single instance attribute" do
      registry.define_instance_attributes([:instance_attr], options: { readonly: false }, block: lambda(&:to_s))

      result = registry.fetch_attribute(:instance, :instance_attr)

      expect(result).to be_a(Cattri::Attribute)
      expect(result.to_h).to include(name: :instance_attr, level: :instance, readonly: false)
    end

    it "defines multiple instance attribute" do
      registry.define_instance_attributes(%i[instance_attr_a instance_attr_b], options: { reader: false })

      result = registry.defined_attributes(:instance)

      expect(result.size).to eq(2)
      expect(result.keys).to eq(%i[instance_attr_a instance_attr_b])
    end
  end

  describe "#redefine_attribute!" do
    before do
      allow(context).to receive(:clear_defined_methods_for!)
      allow(registry).to receive(:defer_definition)
    end

    it "defers the redefinition if context.defer_definitions? is true" do
      allow(context).to receive(:defer_definitions?).and_return(true)

      registry.redefine_attribute!(class_attribute)

      expect(context).not_to have_received(:clear_defined_methods_for!)
      expect(registry).to have_received(:defer_definition)
        .with(class_attribute)
    end

    it "redefines the attribute via Cattri::AttributeCompiler" do
      allow(context).to receive(:defer_definitions?).and_return(false)
      allow(Cattri::AttributeCompiler).to receive(:class_accessor)

      registry.redefine_attribute!(class_attribute)

      expect(registry).not_to have_received(:defer_definition)
      expect(Cattri::AttributeCompiler).to have_received(:class_accessor)
        .with(class_attribute, context)
    end

    it "raises an error when attempting to redefine a finalized attribute" do
      allow(class_attribute).to receive(:final?).and_return(true)

      expect do
        registry.redefine_attribute!(class_attribute)
      end.to raise_error(Cattri::FinalAttributeError, /Class attribute :#{class_attribute.name}/)
    end
  end

  describe "#redefine_attribute_setter!" do
    it "redefines the attribute's setter" do
      allow(registry).to receive(:redefine_attribute!)

      block = lambda(&:to_i)
      registry.redefine_attribute_setter!(instance_attribute, block)

      expect(instance_attribute.setter).to eq(block)
      expect(registry).to have_received(:redefine_attribute!).with(instance_attribute)
    end

    it "raises an error when the attribute provided is nil" do
      expect do
        registry.redefine_attribute_setter!(nil, nil)
      end.to raise_error(Cattri::EmptyAttributeError)
    end

    it "raises an error when the block provided is nil" do
      expect do
        registry.redefine_attribute_setter!(instance_attribute, nil)
      end.to raise_error(Cattri::MissingBlockError, /#{instance_attribute.name}/)
    end

    it "raises an error when attempting to redefine a finalized attribute" do
      allow(class_attribute).to receive(:final?).and_return(true)

      expect do
        registry.redefine_attribute_setter!(class_attribute, lambda(&:to_i))
      end.to raise_error(Cattri::FinalAttributeError, /#{class_attribute.name}/)
    end
  end

  describe "private methods" do
    describe "#__defined_attributes" do
      before do
        registry.instance_variable_set(:@__defined_attributes, defined_attributes)
      end

      it "returns a hash of registered attributes by level" do
        result = registry.__send__(:__defined_attributes)

        expect(result).to include(
          class: { class_attribute.name => class_attribute },
          instance: { instance_attribute.name => instance_attribute }
        )
      end
    end

    describe "#apply_copied_attributes" do
      it "processes and registers copied attributes, temporarily changing the context" do
        allow(Cattri::AttributeCompiler).to receive(:class_accessor)

        registry.send(:apply_copied_attributes, class_attribute, target_context: ancestor_context)

        expect(Cattri::AttributeCompiler).to have_received(:class_accessor)
          .once
          .with(class_attribute, ancestor_context)

        expect(registry.context).to eq(context)
      end
    end

    describe "#define_attributes" do
      it "defines the attributes" do
        allow(registry).to receive(:define_attribute)

        registry.send(:define_attributes, %i[attr_a attr_b], :class, {}, nil)

        expect(registry).to have_received(:define_attribute).exactly(2).times
      end

      it "raises an error when a predicate name is given" do
        expect do
          registry.send(:define_attributes, [:attr?], :instance, {}, nil)
        end.to raise_error(Cattri::AttributeError, /Attribute names ending in '\?'/)
      end

      it "raises an when an unsupported level is provided" do
        expect do
          registry.send(:define_attributes, [:attr], :unknown, {}, nil)
        end.to raise_error(Cattri::UnsupportedAttributeLevelError, /:unknown/)
      end

      it "raises an error when block is provided with multiple attributes" do
        expect do
          registry.send(:define_attributes, %i[class_attr_a class_attr_b], :class, {}, lambda(&:to_s))
        end.to raise_error(Cattri::AmbiguousBlockError)
      end
    end

    describe "#define_attribute" do
      it "instantiates and registers an attribute" do
        registry.send(:define_attribute, :test, :class, {}, nil)

        expect(registry.defined_attributes(:class).keys).to include(:test)
      end
    end

    describe "#process_attribute" do
      before do
        allow(registry).to receive(:defer_definition)
        allow(registry).to receive(:apply_definition!)
      end

      it "registers the attribute" do
        expect(registry.fetch_attribute(:instance, instance_attribute.name)).to be_nil

        registry.send(:process_attribute, instance_attribute)

        expect(registry.fetch_attribute(:instance, instance_attribute.name)).to eq(instance_attribute)
      end

      it "defers the definition if context.defer_definitions? is true" do
        allow(context).to receive(:defer_definitions?).and_return(true)

        registry.send(:process_attribute, instance_attribute)

        expect(registry).not_to have_received(:apply_definition!)
        expect(registry).to have_received(:defer_definition)
          .with(instance_attribute)
      end

      it "applies the definition when context.defer_definitions? is false" do
        allow(context).to receive(:defer_definitions?).and_return(false)

        registry.send(:process_attribute, instance_attribute)

        expect(registry).not_to have_received(:defer_definition)
        expect(registry).to have_received(:apply_definition!)
          .with(instance_attribute)
      end

      it "raises an error when the attribute is already defined" do
        registry.send(:process_attribute, instance_attribute)

        expect do
          registry.send(:process_attribute, instance_attribute)
        end.to raise_error(Cattri::AttributeDefinedError, /Instance attribute :#{instance_attribute.name}/)
      end
    end

    describe "#defer_definition" do
      before do
        allow(context).to receive(:ensure_deferred_support!)
        allow(klass).to receive(:defer_attribute)
      end

      it "passes the attribute to context.target to defer" do
        registry.send(:defer_definition, instance_attribute)

        expect(context).to have_received(:ensure_deferred_support!)
        expect(klass).to have_received(:defer_attribute)
          .with(instance_attribute)
      end
    end

    describe "#apply_definition!" do
      before do
        allow(Cattri::AttributeCompiler).to receive(:class_accessor)
        allow(Cattri::AttributeCompiler).to receive(:instance_accessor)
      end

      it "calls AttributeCompiler.class_accessor with the class-level attribute" do
        registry.send(:apply_definition!, class_attribute)

        expect(Cattri::AttributeCompiler).to have_received(:class_accessor)
          .with(class_attribute, context)
      end

      it "calls AttributeCompiler.instance_accessor with the instance-level attribute" do
        registry.send(:apply_definition!, instance_attribute)

        expect(Cattri::AttributeCompiler).to have_received(:instance_accessor)
          .with(instance_attribute, context)
      end

      it "raises an error when the call to Cattri::AttributeCompiler fails" do
        allow(Cattri::AttributeCompiler).to receive(:class_accessor).and_raise(Cattri::Error, "failed")

        expect do
          registry.send(:apply_definition!, class_attribute)
        end.to raise_error(Cattri::AttributeDefinitionError, /#{class_attribute.name}/)
      end
    end
  end
end
