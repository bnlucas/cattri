# frozen_string_literal: true

require "spec_helper"
require "cattri/context"
require "cattri/attribute"

RSpec.describe Cattri::Context do
  let(:klass) do
    Class.new do
      def public_method; end

      private

      def private_method; end

      protected

      def protected_method; end
    end
  end

  let(:context) { described_class.new(klass) }

  describe "#method_defined?" do
    it "returns true for public methods" do
      expect(context.method_defined?(:public_method)).to eq(true)
    end

    it "returns true for private methods" do
      expect(context.method_defined?(:private_method)).to eq(true)
    end

    it "returns true for protected methods" do
      expect(context.method_defined?(:protected_method)).to eq(true)
    end

    it "returns false for undefined methods" do
      expect(context.method_defined?(:undefined)).to eq(false)
    end

    it "returns true for Cattri-defined methods" do
      attr = Cattri::Attribute.new(:foo, :instance, {}, nil)
      context.define_method(attr) { :bar }
      expect(context.method_defined?(:foo)).to eq(true)
    end
  end

  describe "#define_method" do
    let(:attr) do
      Cattri::Attribute.new(:foo, :instance, { access: :private }, nil)
    end

    it "defines method and applies access" do
      context.define_method(attr) { "hello" }
      expect(klass.private_instance_methods).to include(:foo)
      expect(klass.new.send(:foo)).to eq("hello")
    end

    it "does not redefine an existing method" do
      klass.define_method(:foo) { "original" }
      expect do
        context.define_method(attr) { "ignored" }
      end.not_to(change { klass.instance_method(:foo).source_location })
    end

    it "raises an AttributeDefinitionError if method definition fails" do
      allow(klass).to receive(:define_method).and_raise(StandardError, "method definition failed")

      expect do
        context.define_method(attr)
      end.to raise_error(Cattri::AttributeDefinitionError, /Failed to define method :foo/)
    end
  end

  describe "#ivar_set, #ivar_get, #ivar_defined?" do
    it "sets and gets instance variables" do
      context.ivar_set(:x, 99)
      expect(context.ivar_get(:x)).to eq(99)
      expect(context.ivar_defined?(:x)).to eq(true)
    end

    it "returns false for undefined ivars" do
      expect(context.ivar_defined?(:missing)).to eq(false)
    end
  end

  describe "#ivar_memoize" do
    it "returns cached value if already defined" do
      context.ivar_set(:token, "cached")
      expect(context.ivar_memoize(:token, "new")).to eq("cached")
    end

    it "sets and returns new value if undefined" do
      expect(context.ivar_memoize(:foo, 42)).to eq(42)
      expect(context.ivar_get(:foo)).to eq(42)
    end
  end

  describe "private behavior" do
    describe "#validate_access" do
      it "returns valid access levels" do
        %i[public protected private].each do |level|
          expect(context.send(:validate_access, level)).to eq(level)
        end
      end

      it "returns :public and warns for invalid level" do
        expect(context).to receive(:warn).with(/:bogus/)
        expect(context.send(:validate_access, :bogus)).to eq(:public)
      end
    end

    describe "#apply_access" do
      it "does not modify access for public attributes" do
        attr = Cattri::Attribute.new(:foo, :instance, { access: :public }, nil)
        expect(klass).to receive(:define_method).with(:foo).and_call_original
        context.define_method(attr) { "hi" }
      end

      it "applies access using reflection for non-public" do
        attr = Cattri::Attribute.new(:bar, :instance, { access: :private }, nil)
        context.define_method(attr) { "secure" }
        expect(klass.private_instance_methods).to include(:bar)
      end
    end

    describe "#sanitize_ivar" do
      it "normalizes string or symbol to instance variable symbol" do
        expect(context.send(:sanitize_ivar, "test")).to eq(:@test)
        expect(context.send(:sanitize_ivar, :foo)).to eq(:@foo)
        expect(context.send(:sanitize_ivar, "@bar")).to eq(:@bar)
      end
    end
  end
end
