# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Context do
  let(:context_target) { Class.new }
  let(:class_attribute) { Cattri::Attribute.new(:test_cattr, :class, **attribute_options) }
  let(:instance_attribute) { Cattri::Attribute.new(:test_iattr, :instance, **attribute_options) }
  let(:attribute_options) { {} }

  subject(:context) { described_class.new(context_target) }

  describe "#defer_definitions?" do
    subject(:result) { described_class.new(target).defer_definitions? }

    context "when the target is a Module but NOT a Class" do
      let(:target) { Module.new }
      it { is_expected.to be(true) }
    end

    context "when the target is a Class" do
      let(:target) { Class.new }
      it { is_expected.to be(false) }
    end
  end

  describe "#ensure_deferred_support!" do
    let(:context_target) { Module.new }

    subject(:call) { context.ensure_deferred_support! }

    context "when the target already extends Cattri::DeferredAttributes" do
      let(:context_target) do
        Class.new do
          include Cattri::DeferredAttributes
        end
      end

      it "returns immediately without calling #extend again" do
        expect(context_target).not_to receive(:extend).with(Cattri::DeferredAttributes)
        call
      end
    end

    context "when the target has not yet extended Cattri::DeferredAttributes" do
      it "extends the target with Cattri::DeferredAttributes" do
        expect(context_target).to receive(:extend).with(Cattri::DeferredAttributes).and_call_original
        call
        expect(context_target.singleton_class.ancestors).to include(Cattri::DeferredAttributes)
      end
    end
  end

  describe "#attribute_sources" do
    let(:mod_a) { Module.new }
    let(:mod_b) { Module.new }
    let(:sc_double) { instance_double(Class, included_modules: [mod_b, mod_a]) }

    subject(:sources) { context.attribute_sources }

    before do
      allow(context_target).to receive(:ancestors).and_return([context_target, mod_a, Object])
      allow(context_target).to receive(:singleton_class).and_return(sc_double)
    end

    it "returns an ordered, duplicate-free list of sources" do
      expect(sources).to eq([context_target, mod_a, Object, mod_b])
      expect(sources.size).to eq(sources.uniq.size)
    end

    it "starts with the target itself" do
      expect(sources.first).to equal(context_target)
    end
  end

  describe "#clear_defined_methods_for!" do
    let(:attribute_name) { instance_attribute.name }
    let(:target_spy) { double("TargetSpy") }

    before do
      context.instance_variable_get(:@defined_methods)[attribute_name] << attribute_name

      allow(context).to receive(:target_for).with(instance_attribute).and_return(target_spy)
    end

    it "calls removes the methods from the context target and clears them from the registry" do
      expect(target_spy).to receive(:remove_method).with(attribute_name)

      context.clear_defined_methods_for!(instance_attribute)

      expect(context.instance_variable_get(:@defined_methods)[attribute_name]).to be_empty
    end
  end

  describe "#method_defined?" do
    let(:attribute_name) { class_attribute.name }

    subject(:result) { context.method_defined?(class_attribute) }

    context "when the method is defined directly on the target class" do
      before do
        context.send(:target_for, class_attribute)
               .define_method(attribute_name) { "cattri" }
      end

      it { is_expected.to be(true) }
    end

    context "when the method is NOT on the class but is tracked internally" do
      before do
        context.instance_variable_get(:@defined_methods)[attribute_name] << attribute_name
      end

      it { is_expected.to be(true) }
    end

    context "when the method is neither on the class nor tracked" do
      it { is_expected.to be(false) }
    end

    context "when a different :name argument is supplied" do
      before do
        context.send(:target_for, class_attribute)
               .define_method(attribute_name) { "cattri" }
      end

      it "checks the explicitly-passed name, not the attribute’s name" do
        expect(context.method_defined?(class_attribute, name: attribute_name)).to be(true)
        expect(context.method_defined?(class_attribute, name: :foo)).to be(false)
      end
    end
  end

  describe "#define_method" do
    let(:attribute_name) { class_attribute.name }
    let(:impl) { proc { :something } }
    let(:target) { context.send(:target_for, class_attribute) }

    def stub_method_defined?(flag, attribute)
      allow(context).to receive(:method_defined?)
        .with(attribute, name: attribute.name).and_return(flag)
    end

    context "when the method does not exist" do
      before { stub_method_defined?(false, class_attribute) }

      it "delegates to #define_method!" do
        expect(context).to receive(:define_method!)
          .with(target, class_attribute, attribute_name, &impl)

        context.define_method(class_attribute, &impl)
      end
    end

    context "when the method already exists but attribute[:force] is true" do
      let(:attribute_options) { { force: true } }

      before { stub_method_defined?(true, class_attribute) }

      it "delegates to #define_method! with the resolved args" do
        expect(context).to receive(:define_method!)
          .with(target, class_attribute, attribute_name, &impl)

        context.define_method(class_attribute, &impl)
      end
    end

    context "when the method already exists and attribute[:force] is false" do
      before { stub_method_defined?(true, class_attribute) }

      it "raises Cattri::MethodDefinedError and never calls #define_method!" do
        expect(context).not_to receive(:define_method!)

        expect do
          context.define_method(class_attribute, &impl)
        end.to raise_error(Cattri::MethodDefinedError, /Method `:#{attribute_name}` already exists/)
      end
    end
  end

  describe "private methods" do
    describe "#normalize_target" do
      let(:context_target) { Class.new }

      subject(:normalized) { context.send(:normalize_target, target) }

      context "with an ordinary class (early-return branch)" do
        let(:target) { context_target }
        it { is_expected.to equal(context_target) }
      end

      context "with a class eigen-class (superclass branch)" do
        let(:target) { context_target.singleton_class }

        it "returns that eigen-class’s superclass" do
          expect(normalized).to equal(target.superclass)
        end
      end

      context "with a singleton class whose superclass is nil (fallback branch)" do
        let(:target) do
          singleton = context_target.singleton_class
          singleton.define_singleton_method(:superclass) { nil }

          singleton
        end

        it { is_expected.to equal(target) }
      end
    end

    describe "#singleton_class?" do
      subject(:result) { context.send(:singleton_class?, target) }

      context "when the object really is a singleton class" do
        let(:target) { context_target.singleton_class }
        it { is_expected.to be(true) }
      end

      context "when the object is an ordinary (non-singleton) class" do
        let(:target) { context_target }
        it { is_expected.to be(false) }
      end

      context "when #singleton_class? is missing and the fallback returns false" do
        let(:target) { Object.new }
        it { is_expected.to be(false) }
      end

      context "when #singleton_class? is missing and the fallback returns true" do
        let(:target) do
          Object.new.tap do |o|
            def o.to_s
              "#<Class:fake>"
            end
          end
        end

        it { is_expected.to be(true) }
      end
    end

    describe "#define_method!" do
      let(:target) { context.send(:target_for, class_attribute) }
      let(:attribute_name) { class_attribute.name }
      let(:implementation) { proc { :impl } }

      context "when method definition succeeds" do
        before { allow(context).to receive(:apply_access) }

        it "defines the method, tracks it, and applies access" do
          context.send(:define_method!, target, class_attribute, attribute_name, &implementation)

          expect(target.instance_method(attribute_name)).to be_a(UnboundMethod)
          expect(context_target.send(attribute_name)).to eq(:impl)

          defined_set = context.instance_variable_get(:@defined_methods)[attribute_name]
          expect(defined_set).to include(attribute_name)

          expect(context).to have_received(:apply_access)
            .with(target, attribute_name, class_attribute)
        end
      end

      context "when `class_eval` raises an error" do
        before do
          allow(target).to receive(:class_eval).and_raise(StandardError, "boom")
        end

        it "wraps the error in AttributeDefinitionError" do
          expect do
            context.send(:define_method!, target, class_attribute, attribute_name, &implementation)
          end.to raise_error(Cattri::AttributeDefinitionError, /Failed to define method :#{attribute_name}/)

          registry = context.instance_variable_get(:@defined_methods)[attribute_name]
          expect(registry).to be_empty
        end
      end
    end

    describe "#target_for" do
      subject(:result) { context.send(:target_for, attribute) }

      context "when a class-level attribute is provided" do
        let(:attribute) { class_attribute }

        it "returns the singleton_class" do
          expect(result).to eq(context_target.singleton_class)
        end
      end

      context "when a instance-level attribute is provided" do
        let(:attribute) { instance_attribute }

        it "returns the context's target" do
          expect(result).to eq(context_target)
        end
      end
    end

    describe "#resolve_access" do
      subject(:result) { context.send(:resolve_access, access) }

      %i[public protected private].each do |access|
        context "when access is :#{access}" do
          let(:access) { access }
          it { is_expected.to eq(access) }
        end
      end

      context "when access is nil" do
        let(:access) { nil }
        it { is_expected.to eq(:public) }
      end

      context "when access is something else" do
        let(:access) { :foo }

        it "warns and returns :public" do
          allow(context).to receive(:warn)

          expect(result).to eq(:public)
          expect(context).to have_received(:warn)
            .with("[Cattri] `:foo` is not a supported access level, defaulting to :public")
        end
      end
    end

    describe "#apply_access" do
      let(:target) { context.send(:target_for, attribute) }
      let(:unbound_method) { instance_double(UnboundMethod) }
      let(:unbound) { instance_double(Method) }
      let(:name) { :foo }

      subject(:call) { context.send(:apply_access, target, name, attribute) }

      context "when attribute.access == :public" do
        let(:attribute) { Cattri::Attribute.new(:test_cattr, :class, access: :public) }

        it "returns immediately" do
          call

          expect(context).not_to receive(:resolve_access)
          expect(context).not_to receive(:target_for)
          expect(Module).not_to receive(:instance_method)
        end
      end

      context "when attribute.access == :protected" do
        let(:attribute) { Cattri::Attribute.new(:test_cattr, :class, access: :protected) }

        it "applies protected visibility to the attribute method definition" do
          expect(Module).to receive(:instance_method).with(:protected).and_return(unbound_method)
          expect(unbound_method).to receive(:bind).with(target).and_return(unbound)
          expect(unbound).to receive(:call).with(name)

          call
        end
      end
    end
  end
end
