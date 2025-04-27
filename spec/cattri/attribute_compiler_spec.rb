# frozen_string_literal: true

require "spec_helper"
require "cattri/attribute"
require "cattri/context"
require "cattri/attribute_compiler"

RSpec.describe Cattri::AttributeCompiler do
  let!(:class_attribute) do
    Cattri::Attribute.new(name, :class, **options, &block)
  end

  let(:instance_attribute) do
    Cattri::Attribute.new(name, :instance, **options, &block)
  end

  let(:name) { :cattri_attr }
  let(:default) { "cattri" }
  let(:access) { :public }
  let(:predicate) { false }
  let(:readonly) { false }
  let(:instance_reader) { true }
  let(:reader) { true }
  let(:writer) { true }
  let(:options) do
    {
      default: default,
      access: access,
      predicate: predicate,
      readonly: readonly,
      instance_reader: instance_reader,
      reader: reader,
      writer: writer
    }
  end

  let(:block) { lambda(&:to_s) }
  let(:klass) { Class.new }
  let!(:context) { Cattri::Context.new(klass) }

  subject(:compiler) { described_class }

  before do
    allow(context).to receive(:define_method)
    allow(context.target).to receive(:define_method)
  end

  describe ".class_accessor" do
    before do
      allow(compiler).to receive(:class_writer)
      allow(compiler).to receive(:class_predicate)
      allow(compiler).to receive(:delegate_to_class_reader)

      compiler.class_accessor(class_attribute, context)
    end

    it "calls context.define_method" do
      expect(context).to have_received(:define_method)
        .with(class_attribute)
    end

    [true, false].each do |state|
      context "when attribute[:readonly] is #{state}" do
        let(:readonly) { state }

        it "#{state ? "does not call" : "calls"} .class_writer(attribute, context)" do
          expect(compiler).send(
            state ? :not_to : :to,
            have_received(:class_writer).with(class_attribute, context)
          )
        end
      end

      context "when attribute[:predicate] is #{state}" do
        let(:predicate) { state }

        it "#{state ? "calls" : "does not call"} .class_predicate(attribute, context)" do
          expect(compiler).send(
            state ? :to : :not_to,
            have_received(:class_predicate).with(class_attribute, context)
          )
        end
      end

      context "when attribute[:instance_reader] is #{state}" do
        let(:instance_reader) { state }

        it "#{state ? "calls" : "does not call"} .delegate_to_class_reader(attribute, context)" do
          expect(compiler).send(
            state ? :to : :not_to,
            have_received(:delegate_to_class_reader).with(class_attribute, context)
          )
        end
      end
    end
  end

  describe ".class_writer" do
    before do
      allow(compiler).to receive(:define_writer)

      compiler.class_writer(class_attribute, context)
    end

    it "calls .define_writer" do
      expect(compiler).to have_received(:define_writer)
        .with(class_attribute, context)
    end
  end

  describe ".class_predicate" do
    before do
      allow(compiler).to receive(:define_predicate)
      allow(compiler).to receive(:delegate_to_class_predicate)

      compiler.class_predicate(class_attribute, context)
    end

    it "calls .define_predicate" do
      expect(compiler).to have_received(:define_predicate)
        .with(class_attribute, context)
    end

    [true, false].each do |state|
      context "when attribute[:instance_reader] is #{state}" do
        let(:instance_reader) { state }

        it "#{state ? "calls" : "does not call"} .delegate_to_class_predicate(attribute, context)" do
          expect(compiler).send(
            state ? :to : :not_to,
            have_received(:delegate_to_class_predicate).with(class_attribute, context)
          )
        end
      end
    end
  end

  describe ".delegate_to_class_reader" do
    before do
      allow(compiler).to receive(:delegate_to_class)

      compiler.delegate_to_class_reader(class_attribute, context)
    end

    it "calls .delegate_to_class" do
      expect(compiler).to have_received(:delegate_to_class)
        .with(class_attribute.name, context)
    end
  end

  describe ".delegate_to_class_predicate" do
    before do
      allow(compiler).to receive(:delegate_to_class)

      compiler.delegate_to_class_predicate(class_attribute, context)
    end

    it "calls .delegate_to_class" do
      expect(compiler).to have_received(:delegate_to_class)
        .with(:"#{class_attribute.name}?", context)
    end
  end

  describe ".instance_accessor" do
    before do
      allow(compiler).to receive(:instance_reader)
      allow(compiler).to receive(:instance_writer)
      allow(compiler).to receive(:instance_predicate)

      compiler.instance_accessor(instance_attribute, context)
    end

    [true, false].each do |state|
      context "when attribute[:reader] is #{state}" do
        let(:reader) { state }

        it "#{state ? "calls" : "does not call"} .instance_reader(attribute, context)" do
          expect(compiler).send(
            state ? :to : :not_to,
            have_received(:instance_reader).with(instance_attribute, context)
          )
        end
      end

      context "when attribute[:writer] is #{state}" do
        let(:writer) { state }

        it "#{state ? "calls" : "does not call"} .instance_writer(attribute, context)" do
          expect(compiler).send(
            state ? :to : :not_to,
            have_received(:instance_writer).with(instance_attribute, context)
          )
        end
      end

      context "when attribute[:predicate] is #{state}" do
        let(:predicate) { state }

        it "#{state ? "calls" : "does not call"} .instance_predicate(attribute, context)" do
          expect(compiler).send(
            state ? :to : :not_to,
            have_received(:instance_predicate).with(instance_attribute, context)
          )
        end
      end
    end
  end

  describe ".instance_reader" do
    before do
      compiler.instance_reader(instance_attribute, context)
    end

    it "calls context.define_method" do
      expect(context).to have_received(:define_method)
        .with(instance_attribute)
    end
  end

  describe ".instance_writer" do
    before do
      allow(compiler).to receive(:define_writer)

      compiler.instance_writer(instance_attribute, context)
    end

    it "calls .define_writer" do
      expect(compiler).to have_received(:define_writer)
        .with(instance_attribute, context)
    end
  end

  describe ".instance_predicate" do
    before do
      allow(compiler).to receive(:define_predicate)

      compiler.instance_predicate(instance_attribute, context)
    end

    it "calls .define_predicate" do
      expect(compiler).to have_received(:define_predicate)
        .with(instance_attribute, context)
    end
  end

  describe "private methods" do
    describe ".define_writer" do
      before { compiler.send(:define_writer, instance_attribute, context) }

      it "calls context.define_method" do
        expect(context).to have_received(:define_method)
          .with(instance_attribute, name: :"#{instance_attribute.name}=")
      end
    end

    describe ".define_predicate" do
      before { compiler.send(:define_predicate, instance_attribute, context) }

      it "calls context.define_method" do
        expect(context).to have_received(:define_method)
          .with(instance_attribute, name: :"#{instance_attribute.name}?")
      end
    end

    describe ".delegate_to_class" do
      before { compiler.send(:delegate_to_class, name, context) }

      it "calls context.define_method" do
        expect(context.target).to have_received(:define_method)
          .with(name)
      end
    end

    describe ".memoize_default_value" do
      before do
        allow(klass).to receive(:instance_variable_get).and_call_original
        allow(klass).to receive(:instance_variable_set).and_call_original
      end

      context "when ivar is present" do
        before { klass.instance_variable_set(instance_attribute.ivar, "test") }

        it "returns the memoized value" do
          result = compiler.send(:memoize_default_value, klass, instance_attribute)

          expect(result).to eq("test")
          expect(klass).to have_received(:instance_variable_get)
        end
      end

      context "when ivar is not present" do
        it "returns the memoized value" do
          result = compiler.send(:memoize_default_value, klass, instance_attribute)

          expect(result).to eq(default)
          expect(klass).to have_received(:instance_variable_set)
        end
      end
    end

    describe ".validate_level!" do
      it "does not raise an error when the attribute level matches the provided level" do
        expect do
          compiler.send(:validate_level!, instance_attribute, :instance)
        end.not_to raise_error
      end

      it "raises an error when the attribute level differs from the provided level" do
        expect do
          compiler.send(:validate_level!, instance_attribute, :class)
        end.to raise_error(Cattri::InvalidAttributeContextError, /Expected :class, got :instance/)
      end
    end
  end

  describe "attribute level validations" do
    describe "providing instance-level attributes to class compilers" do
      %i[
        class_accessor
        class_writer
        class_predicate
        delegate_to_class_reader
        delegate_to_class_predicate
      ].each do |method|
        it "raises an error when calling `.#{method}`" do
          expect do
            compiler.send(method, instance_attribute, context)
          end.to raise_error(Cattri::Error)
        end
      end
    end

    describe "providing class-level attributes to instance compilers" do
      %i[
        instance_accessor
        instance_reader
        instance_writer
        instance_predicate
      ].each do |method|
        it "raises an error when calling `.#{method}`" do
          expect do
            compiler.send(method, class_attribute, context)
          end.to raise_error(Cattri::Error)
        end
      end
    end
  end
end
