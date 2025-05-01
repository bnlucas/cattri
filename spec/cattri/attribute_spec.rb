# frozen_string_literal: true

RSpec.describe Cattri::Attribute do
  let(:name) { :attr }
  let(:klass) { Class.new }
  let(:final) { true }
  let(:expose) { :read_write }
  let(:scope) { :class }
  let(:predicate) { false }
  let(:default) { "default" }
  let(:transformer) { ->(value) { value } }

  subject(:attribute) do
    described_class.new(
      name,
      defined_in: klass,
      final: final,
      expose: expose,
      scope: scope,
      predicate: predicate,
      default: default,
      transformer: transformer
    )
  end

  describe "#initialize" do
    it "instantiates an Attribute" do
      expect(attribute).to be_a(described_class)
      expect(attribute.defined_in).to eq(klass)
    end
  end

  describe "#to_h" do
    it "returns the Cattri::AttributeOptions hash" do
      hash = attribute.to_h
      options_hash = attribute.instance_variable_get(:@options).to_h

      expect(hash).to be_a(Hash)
      expect(hash).to eq(options_hash.merge(defined_in: klass))
    end
  end

  %i[
    name
    ivar
    default
    transformer
    expose
    visibility
  ].each do |option|
    describe "##{option}" do
      it "proxies to @options.#{option}" do
        result = attribute.public_send(option)
        options_value = attribute.instance_variable_get(:@options).public_send(option)

        expect(result).to eq(options_value)
      end
    end
  end

  describe "#internal_reader?" do
    [
      [:read, false],
      [:write, true],
      [:read_write, false],
      [:none, true]
    ].each do |(value, expected)|
      context "when instantiated with `expose: :#{value}`" do
        let(:expose) { value }

        it "returns #{expected}" do
          expect(attribute.internal_reader?).to eq(expected)
        end
      end
    end
  end

  describe "#internal_writer?" do
    [
      [:read, true],
      [:write, false],
      [:read_write, false],
      [:none, true]
    ].each do |(value, expected)|
      context "when instantiated with `expose: :#{value}`" do
        let(:expose) { value }

        it "returns #{expected}" do
          expect(attribute.internal_writer?).to eq(expected)
        end
      end
    end
  end

  describe "#readable?" do
    [
      [:read, true],
      [:write, false],
      [:read_write, true],
      [:none, false]
    ].each do |(value, expected)|
      context "when instantiated with `expose: #{value}`" do
        let(:expose) { value }

        it "returns #{expected}" do
          expect(attribute.readable?).to eq(expected)
        end
      end
    end
  end

  describe "#writable?" do
    [
      [true, :read, false],
      [true, :write, false],
      [true, :read_write, false],
      [true, :none, false],
      [false, :read, false],
      [false, :write, true],
      [false, :read_write, true],
      [false, :none, false]
    ].each do |(final_value, expose_value, expected)|
      context "when instantiated with `final: #{final_value}, expose: #{expose_value}`" do
        let(:final) { final_value }
        let(:expose) { expose_value }

        it "returns #{expected}" do
          expect(attribute.writable?).to eq(expected)
        end
      end
    end
  end

  describe "#readonly?" do
    [
      [true, :read, true],
      [true, :write, true],
      [true, :read_write, true],
      [true, :none, false],
      [false, :read, true],
      [false, :write, false],
      [false, :read_write, false],
      [false, :none, false]
    ].each do |(final_value, expose_value, expected)|
      context "when instantiated with `final: #{final_value}, expose: #{expose_value}`" do
        let(:final) { final_value }
        let(:expose) { expose_value }

        it "returns #{expected}" do
          expect(attribute.readonly?).to eq(expected)
        end
      end
    end
  end

  describe "#final?" do
    [true, false].each do |value|
      context "when instantiated with `final: #{value}`" do
        let(:final) { value }

        it "returns #{value}" do
          expect(attribute.final?).to eq(value)
        end
      end
    end
  end

  describe "#class_attribute?" do
    %i[class instance].each do |value|
      context "when instantiated with `scope: #{value}`" do
        let(:scope) { value }

        it "returns #{value}" do
          expect(attribute.class_attribute?).to eq(value == :class)
        end
      end
    end
  end

  describe "#with_predicate?" do
    [true, false].each do |value|
      context "when instantiated with `predicate: #{value}`" do
        let(:predicate) { value }

        it "returns #{value}" do
          expect(attribute.with_predicate?).to eq(value)
        end
      end
    end
  end

  describe "#allowed_methods" do
    shared_examples_for "allowed method set" do |writable, predicate, expected|
      let(:expose) { writable ? :read_write : :read }
      let(:predicate) { predicate }
      let(:final) { false }

      it "returns #{expected.inspect} for writable: #{writable}, predicate: #{predicate}" do
        expect(attribute.allowed_methods).to eq(expected)
      end
    end

    it_behaves_like "allowed method set", true,  true,  %i[attr attr= attr?]
    it_behaves_like "allowed method set", true,  false, %i[attr attr=]
    it_behaves_like "allowed method set", false, true,  %i[attr attr?]
    it_behaves_like "allowed method set", false, false, [:attr]
  end

  describe "#validate_assignment!" do
    [
      [true, :read, true, false],
      [true, :write, true, false],
      [true, :read_write, true, false],
      [true, :none, true, false],
      [false, :read, false, true],
      [false, :write, false, false],
      [false, :read_write, false, false],
      [false, :none, false, false]
    ].each do |(final_value, expose_value, raise_final, raise_readonly)|
      context "when instantiated with `final: #{final_value}, expose: #{expose_value}`" do
        let(:final) { final_value }
        let(:expose) { expose_value }

        it "raises an error" do
          message =
            if raise_final
              "Cannot assign to final attribute `:#{attribute.name}`"
            elsif raise_readonly
              "Cannot assign to readonly attribute `:#{attribute.name}`"
            end

          if raise_final || raise_readonly
            expect { attribute.validate_assignment! }
              .to raise_error(Cattri::AttributeError, message)
          end
        end
      end
    end

    context "when instantiated with `final: false, expose: :read_write`" do
      let(:final) { false }
      let(:expose) { :read_write }

      it "does not raise an error" do
        expect { attribute.validate_assignment! }.not_to raise_error
      end
    end
  end

  describe "#evaluate_default" do
    context "when the default value succeeds" do
      it "calls the transformer and returns the result" do
        expect(attribute.evaluate_default).to eq(default)
      end
    end

    context "when the default value raises an error" do
      let(:default) { double("invalid") }

      before do
        allow(default).to receive(:dup).and_raise(TypeError, "boom")
      end

      it "raises Cattri::AttributeError" do
        expect { attribute.evaluate_default }
          .to raise_error(
            Cattri::AttributeError,
            "Failed to evaluate the default value for `:#{attribute.name}`. Error: boom"
          )
      end
    end
  end

  describe "#process_assignment" do
    context "when the transformer succeeds" do
      it "calls the transformer and returns the result" do
        expect(attribute.process_assignment("cattri")).to eq("cattri")
      end
    end

    context "when the transformer raises an error" do
      let(:transformer) { double("invalid") }

      before do
        allow(transformer).to receive(:call).and_raise(TypeError, "boom")
      end

      it "raises Cattri::AttributeError" do
        expect { attribute.process_assignment(1, a: 2) }
          .to raise_error(
            Cattri::AttributeError,
            "Failed to evaluate the setter for `:#{attribute.name}`. Error: boom"
          )
      end
    end
  end
end
