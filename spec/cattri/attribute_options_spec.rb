# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::AttributeOptions do
  describe ".validate_expose!" do
    subject(:instance) { described_class.new(:attr) }

    it "returns the valid option provided" do
      expect(described_class.validate_expose!(:read)).to eq(:read)
    end

    it "returns the valid option provided from a string" do
      expect(described_class.validate_expose!("read")).to eq(:read)
    end

    it "raises on an invalid option" do
      expect do
        described_class.validate_expose!(:invalid)
      end.to raise_error(Cattri::AttributeError, /Invalid expose option `:invalid`/)
    end
  end

  describe ".validate_visibility!" do
    subject(:instance) { described_class.new(:attr) }

    it "returns the valid option provided" do
      expect(described_class.validate_visibility!(:public)).to eq(:public)
    end

    it "returns the valid option provided from a string" do
      expect(described_class.validate_visibility!("public")).to eq(:public)
    end

    it "raises on an invalid option" do
      expect do
        described_class.validate_visibility!(:invalid)
      end.to raise_error(Cattri::AttributeError, /Invalid visibility `:invalid`/)
    end
  end

  describe "#initialize" do
    let(:name) { :my_attribute }

    it "sets @name to symbolized name" do
      instance = described_class.new(name)
      expect(instance.instance_variable_get(:@name)).to eq(:my_attribute)
    end

    context "with default options" do
      subject(:instance) { described_class.new(name) }

      it "sets @ivar to normalized default" do
        expect(instance.instance_variable_get(:@ivar)).to eq(:@my_attribute)
      end

      it "sets @final to false" do
        expect(instance.instance_variable_get(:@final)).to be(false)
      end

      it "sets @scope to :instance" do
        expect(instance.instance_variable_get(:@scope)).to be(:instance)
      end

      it "sets @predicate to false" do
        expect(instance.instance_variable_get(:@predicate)).to be(false)
      end

      it "sets @default using normalize_default" do
        expect(instance.instance_variable_get(:@default).call).to eq(nil)
      end

      it "sets @transformer using normalize_transformer" do
        transformer = instance.instance_variable_get(:@transformer)
        expect(transformer).to respond_to(:call)
      end

      it "sets @expose using validate_expose!" do
        expect(instance.instance_variable_get(:@expose)).to eq(:read_write)
      end

      it "sets @visibility using validate_visibility!" do
        expect(instance.instance_variable_get(:@visibility)).to eq(:public)
      end

      it "freezes the instance" do
        expect(instance).to be_frozen
      end
    end

    context "with provided options" do
      let(:ivar) { :custom_ivar }
      let(:final) { true }
      let(:scope) { :class }
      let(:predicate) { true }
      let(:default) { :custom_default }
      let(:transformer) { ->(val) { val } }
      let(:expose) { :read }
      let(:visibility) { :private }

      subject(:instance) do
        described_class.new(
          name,
          ivar: ivar,
          final: final,
          scope: scope,
          predicate: predicate,
          default: default,
          transformer: transformer,
          expose: expose,
          visibility: visibility
        )
      end

      it "assigns the custom ivar" do
        expect(instance.instance_variable_get(:@ivar)).to eq(:@custom_ivar)
      end

      it "assigns the custom final value" do
        expect(instance.instance_variable_get(:@final)).to eq(true)
      end

      it "assigns the custom scope value" do
        expect(instance.instance_variable_get(:@scope)).to eq(:class)
      end

      it "assigns the custom predicate value" do
        expect(instance.instance_variable_get(:@predicate)).to eq(true)
      end

      it "assigns the custom default value" do
        expect(instance.instance_variable_get(:@default).call).to eq(:custom_default)
      end

      it "assigns the custom transformer" do
        expect(instance.instance_variable_get(:@transformer)).to eq(transformer)
      end

      it "assigns the custom expose value" do
        expect(instance.instance_variable_get(:@expose)).to eq(:read)
      end

      it "assigns the custom visibility value" do
        expect(instance.instance_variable_get(:@visibility)).to eq(:private)
      end
    end
  end

  describe "#[]" do
    subject(:instance) { described_class.new(:attr) }

    it "returns for known options" do
      expect(instance[:name]).to eq(:attr)
    end

    it "returns nil for unknown options" do
      expect(instance[:unknown]).to be_nil
    end

    it "converts the key provided to a symbol" do
      expect(instance["ivar"]).to eq(:@attr)
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the options" do
      instance = described_class.new(:attr, ivar: :custom_ivar)
      hash = instance.to_h

      expect(hash).to be_frozen
      expect(hash).to include(
        name: :attr,
        ivar: :@custom_ivar,
        final: false,
        scope: :instance,
        predicate: false,
        expose: :read_write,
        visibility: :public
      )

      expect(hash[:default].call).to be_nil
      expect(hash[:transformer].call(123)).to be(123)
    end
  end

  describe "#normalize_ivar" do
    subject(:instance) { described_class.new(:attr) }

    [
      [nil, :@attr],
      %i[@custom @custom],
      ["@_custom", :@_custom],
      %i[@__custom @__custom]
    ].each do |(ivar, expected)|
      it "returns #{expected.inspect} for '#{ivar}'" do
        expect(instance.send(:normalize_ivar, ivar)).to eq(expected)
      end
    end
  end

  describe "#normalize_default" do
    subject(:instance) { described_class.new(:attr) }

    it "returns existing callable unchanged" do
      fn = -> { :ok }
      default = instance.send(:normalize_default, fn)

      expect(default).to be_a(Proc)
      expect(default.call).to eq(fn.call)
    end

    it "wraps immutable value in lambda" do
      default = instance.send(:normalize_default, :sym)

      expect(default).to be_a(Proc)
      expect(default.call).to eq(:sym)
    end

    it "wraps mutable values and duplicates them" do
      default = instance.send(:normalize_default, [1, 2])
      v1 = default.call
      v2 = default.call

      expect(v1).to eq([1, 2])
      expect(v1).not_to be(v2)
    end
  end

  describe "#normalize_transformer" do
    subject(:instance) { described_class.new(:attr) }

    it "returns kwargs if no positional args provided" do
      expect(instance.transformer.call(a: 2)).to eq({ a: 2 })
    end

    it "returns single value if one positional arg provided" do
      expect(instance.transformer.call("only")).to eq("only")
    end

    it "returns all positional args if multiple provided without kwargs" do
      expect(instance.transformer.call(1, 2, 3)).to eq([1, 2, 3])
    end

    it "returns positional args and kwargs" do
      expect(instance.transformer.call(1, a: 2)).to eq([1, { a: 2 }])
    end
  end

  describe "#validate_scope!" do
    subject(:instance) { described_class.new(:attr) }

    [
      [nil, :instance],
      %i[instance instance],
      %i[class class]
    ].each do |(scope, expected)|
      it "returns :#{expected} when provided :#{scope}" do
        expect(instance.send(:validate_scope!, scope)).to eq(expected)
      end
    end

    it "raises an error when provided an unknown scope" do
      expect { instance.send(:validate_scope!, :invalid) }
        .to raise_error(Cattri::AttributeError, /Invalid scope `:invalid`/)
    end
  end
end
