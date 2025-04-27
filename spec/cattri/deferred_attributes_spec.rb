# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::DeferredAttributes do
  let(:class_attribute) { Cattri::Attribute.new(:test_cattr, :class) }
  let(:instance_attribute) { Cattri::Attribute.new(:test_iattr, :instance) }

  let(:klass) do
    Class.new do
      include Cattri
      extend Cattri::DeferredAttributes
    end
  end

  let(:context) { Cattri::Context.new(klass) }

  describe "core methods" do
    subject { klass }

    before do
      subject.defer_attribute(class_attribute)
      subject.defer_attribute(instance_attribute)
    end

    describe ".extended" do
      let(:base_module) { Module.new }

      it "prepends Hook if not already present" do
        expect(base_module.singleton_class.ancestors).not_to include(Cattri::DeferredAttributes::Hook)

        described_class.extended(base_module)

        expect(base_module.singleton_class.ancestors).to include(Cattri::DeferredAttributes::Hook)
      end

      it "does not prepend Hook twice" do
        described_class.extended(base_module)
        original_ancestors = base_module.singleton_class.ancestors.dup

        described_class.extended(base_module)

        expect(base_module.singleton_class.ancestors).to eq(original_ancestors)
      end
    end

    describe "defer_attribute" do
      it "stores deferred attributes" do
        deferred_attributes = subject.instance_variable_get(:@deferred_attributes)

        expect(deferred_attributes).to include(
          class: { class_attribute.name => class_attribute },
          instance: { instance_attribute.name => instance_attribute }
        )
      end
    end

    describe "apply_deferred_attributes" do
      before do
        allow(Cattri::Context).to receive(:new).and_return(context)
        allow(Cattri::AttributeCompiler).to receive(:class_accessor)
        allow(Cattri::AttributeCompiler).to receive(:instance_accessor)
      end

      it "applies deferred attributes to the given target" do
        subject.apply_deferred_attributes(klass)

        expect(Cattri::AttributeCompiler).to have_received(:class_accessor).with(class_attribute, context)
        expect(Cattri::AttributeCompiler).to have_received(:instance_accessor).with(instance_attribute, context)
      end
    end
  end

  describe "Cattri::DeferredAttributes::Hook" do
    let(:klass) { Class.new }

    let(:plain_module) do
      Module.new.tap do |mod|
        mod.singleton_class.prepend(Cattri::DeferredAttributes::Hook)
      end
    end

    let(:hook_module) do
      Module.new do
        extend Cattri::DeferredAttributes

        def self.apply_deferred_attributes(_target)
          @called = true
        end
      end
    end

    context "with hooked module" do
      it "triggers apply_deferred_attributes (include)" do
        klass.include(hook_module)
        expect(hook_module.instance_variable_get(:@called)).to eq(true)
      end

      it "triggers apply_deferred_attributes (extend)" do
        klass.extend(hook_module)
        expect(hook_module.instance_variable_get(:@called)).to eq(true)
      end
    end

    context "without hooked module" do
      it "does not call apply_deferred_attributes if not defined (include)" do
        expect { klass.include(plain_module) }.not_to raise_error
      end

      it "does not call apply_deferred_attributes if not defined (extend)" do
        expect { klass.extend(plain_module) }.not_to raise_error
      end
    end
  end
end
