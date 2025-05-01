# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Context do
  let(:context_target) { Class.new }

  def define_attribute(name, value, scope: :instance, visibility: :public)
    Cattri::Attribute.new(
      name,
      default: value,
      scope: scope,
      defined_in: context_target,
      visibility: visibility
    )
  end

  let(:class_attribute) { define_attribute(:class_attr, "class", scope: :class) }
  let(:instance_attribute) { define_attribute(:instance_attr, "instance") }
  let(:attribute_options) { {} }

  subject(:context) { described_class.new(context_target) }

  describe "#initialize" do
    it "instantiates a new Cattri::Context" do
      expect(context).to be_a(described_class)
      expect(context.target).to eq(context_target)
    end
  end

  describe "#defined_methods" do
    it "returns a Hash" do
      expect(context.defined_methods).to be_a(Hash)
    end

    it "returns a frozen object" do
      expect(context.defined_methods).to be_frozen
    end

    it "returns a duplicate of the internal hash" do
      original = { foo: :bar }
      context.instance_variable_set(:@__cattri_defined_methods, original.dup)

      result = context.defined_methods

      expect(result).to eq(original)
      expect(result).not_to equal(original)
    end
  end

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

  describe "#attribute_lookup_sources" do
    let(:mod_a) { Module.new }
    let(:mod_b) { Module.new }
    let(:sc_double) { instance_double(Class, included_modules: [mod_b, mod_a]) }

    subject(:sources) { context.attribute_lookup_sources }

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

    context "when the method already exists" do
      before { stub_method_defined?(true, class_attribute) }

      it "raises Cattri::AttributeError" do
        expect(context).not_to receive(:define_method!)

        expect do
          context.define_method(class_attribute, &impl)
        end.to raise_error(Cattri::AttributeError, /Method `:#{attribute_name}` already defined on #{target}/)
      end
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
      before { context.send(:__cattri_defined_methods)[attribute_name] << attribute_name }
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

  describe "#__cattri_defined_methods" do
    it "returns a Hash" do
      expect(context.send(:__cattri_defined_methods)).to be_a(Hash)
    end

    it "uses a default block to assign empty arrays" do
      hash = context.send(:__cattri_defined_methods)
      hash[:new_key] << :value

      expect(hash[:new_key].to_a).to eq([:value])
    end

    it "memoizes the result" do
      first_call = context.send(:__cattri_defined_methods)
      second_call = context.send(:__cattri_defined_methods)

      expect(first_call).to equal(second_call)
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

  describe "#define_method!" do
    let(:target) { context.send(:target_for, class_attribute) }
    let(:attribute_name) { class_attribute.name }
    let(:implementation) { proc { :impl } }

    context "when method definition succeeds" do
      before { allow(context).to receive(:apply_visibility!) }

      it "defines the method, tracks it, and applies access" do
        context.send(:define_method!, target, class_attribute, attribute_name, &implementation)

        expect(target.instance_method(attribute_name)).to be_a(UnboundMethod)
        expect(context_target.send(attribute_name)).to eq(:impl)

        defined_set = context.send(:__cattri_defined_methods)[attribute_name]
        expect(defined_set).to include(attribute_name)

        expect(context).to have_received(:apply_visibility!)
          .with(target, attribute_name, class_attribute)
      end
    end

    context "when `class_eval` raises an error" do
      before do
        allow(target).to receive(:class_eval).and_raise(StandardError, "boom")
      end

      it "wraps the error in AttributeError" do
        expect do
          context.send(:define_method!, target, class_attribute, attribute_name, &implementation)
        end.to raise_error(Cattri::AttributeError, /#{attribute_name}/)

        defined_set = context.send(:__cattri_defined_methods)[attribute_name]
        expect(defined_set).to be_empty
      end
    end
  end

  describe "#apply_visibility!" do
    let(:target) { context.send(:target_for, attribute) }
    let(:unbound_method) { instance_double(UnboundMethod) }
    let(:unbound) { instance_double(Method) }
    let(:name) { :foo }

    subject(:call) { context.send(:apply_visibility!, target, name, attribute) }

    context "when attribute.access == :public" do
      let(:attribute) { define_attribute(:test_cattr, "test", scope: :class) }

      it "returns immediately" do
        call

        expect(context).not_to receive(:resolve_access)
        expect(context).not_to receive(:target_for)
        expect(Module).not_to receive(:instance_method)
      end
    end

    context "when attribute.access == :protected" do
      let(:attribute) do
        define_attribute(:test_cattr, "test", scope: :class, visibility: :protected)
      end

      it "applies protected visibility to the attribute method definition" do
        expect(Module).to receive(:instance_method).with(:protected).and_return(unbound_method)
        expect(unbound_method).to receive(:bind).with(target).and_return(unbound)
        expect(unbound).to receive(:call).with(name)

        call
      end
    end
  end

  describe "#effective_visibility" do
    before do
      stub_const("Cattri::AttributeOptions", Module.new)
      allow(Cattri::AttributeOptions).to receive(:validate_visibility!).and_return(:explicit)
    end

    it "returns :protected for internal class-level methods" do
      attr = double("Attribute", class_attribute?: true, visibility: nil)
      allow(context).to receive(:internal_method?).with(attr, :foo).and_return(true)

      expect(context.send(:effective_visibility, attr, :foo)).to eq(:protected)
    end

    it "returns :private for internal instance-level methods" do
      attr = double("Attribute", class_attribute?: false, visibility: nil)
      allow(context).to receive(:internal_method?).with(attr, :foo).and_return(true)

      expect(context.send(:effective_visibility, attr, :foo)).to eq(:private)
    end

    it "returns declared visibility for public method" do
      attr = double("Attribute", class_attribute?: false, visibility: :protected)
      allow(context).to receive(:internal_method?).with(attr, :foo).and_return(false)

      expect(context.send(:effective_visibility, attr, :foo)).to eq(:explicit)
    end
  end

  describe "#internal_method?" do
    it "returns true for writer when attribute has no public reader" do
      attr = double("Attribute", internal_writer?: true, internal_reader?: false)
      expect(context.send(:internal_method?, attr, :foo=)).to be true
    end

    it "returns false for writer when attribute has public reader" do
      attr = double("Attribute", internal_writer?: false, internal_reader?: false)
      expect(context.send(:internal_method?, attr, :foo=)).to be false
    end

    it "returns true for reader when attribute has no public writer" do
      attr = double("Attribute", internal_writer?: false, internal_reader?: true)
      expect(context.send(:internal_method?, attr, :foo)).to be true
    end

    it "returns false for reader when attribute has public writer" do
      attr = double("Attribute", internal_writer?: false, internal_reader?: false)
      expect(context.send(:internal_method?, attr, :foo)).to be false
    end
  end
end
