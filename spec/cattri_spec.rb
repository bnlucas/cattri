# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri do
  let(:klass) do
    Class.new do
      include Cattri

      cattri :token, -> { "abc123" }
      cattri :final_token, -> { "321cba" }, final: true
    end
  end

  subject(:instance) { klass.new }

  describe "including Cattri" do
    it "defines a working accessor" do
      expect(instance.token).to eq("abc123")
      instance.token = "xyz"
      expect(instance.token).to eq("xyz")
    end

    it "respects default visibility (public)" do
      expect(klass.public_instance_methods).to include(:token, :token=)
    end

    it "installs initializer patch for default assignment" do
      expect(instance.cattri_variable_defined?(:final_token)).to be true
      expect(instance.cattri_variable_get(:final_token)).to eq("321cba")
    end
  end

  describe ".with_cattri_introspection" do
    let(:introspective_class) do
      Class.new do
        include Cattri
        cattri :id, "foo"

        with_cattri_introspection
      end
    end

    it "adds .attribute_defined?" do
      expect(introspective_class.attribute_defined?(:id)).to be true
      expect(introspective_class.attribute_defined?(:missing)).to be false
    end

    it "returns attribute source and methods" do
      expect(introspective_class.attribute_source(:id)).to eq(introspective_class)
      expect(introspective_class.attribute_methods).to include(:id)
    end
  end

  describe "regression tests" do
    it "allows one-time assignment to final instance attribute" do
      klass = Class.new do
        include Cattri
        cattri :value, final: true

        def initialize(value)
          self.value = value
        end
      end

      instance = klass.new("first")
      expect(instance.value).to eq("first")

      expect { instance.value = "second" }.to raise_error(Cattri::AttributeError)
    end

    it "prevents any assignment to final class attribute" do
      klass = Class.new do
        include Cattri
        cattri :value, -> { "init" }, final: true, scope: :class
      end

      expect(klass.value).to eq("init")
      expect { klass.value = "fail" }.to raise_error(Cattri::AttributeError)
    end

    it "allows shadowing parent class attributes" do
      parent = Class.new do
        include Cattri
        cattri :enabled, true, final: true, scope: :class
      end

      child = Class.new do
        include Cattri
        cattri :enabled, false, final: true, scope: :class
      end

      expect(parent.enabled).to be(true)
      expect(child.enabled).to be(false)
    end

    it "defines predicate method for instance attribute" do
      klass = Class.new do
        include Cattri
        cattri :flag, false, predicate: true
      end

      instance = klass.new
      expect(instance.flag?).to eq(false)

      instance.flag = true
      expect(instance.flag?).to eq(true)
    end

    it "evaluates and stores default value lazily" do
      klass = Class.new do
        include Cattri
        cattri :computed, -> { "value" }
      end

      instance = klass.new

      expect(instance.cattri_variable_defined?(:computed)).to eq(false)
      expect(instance.computed).to eq("value")
      expect(instance.cattri_variable_defined?(:computed)).to eq(true)
    end

    it "isolates instance and class attributes correctly" do
      klass = Class.new do
        include Cattri
        cattri :config, scope: :class
        cattri :state, scope: :instance
      end

      klass.config = "shared"
      a = klass.new
      b = klass.new
      a.state = "one"
      b.state = "two"

      expect(klass.config).to eq("shared")
      expect(a.state).to eq("one")
      expect(b.state).to eq("two")
    end

    it "allows for class attributes set on a module's singleton_class" do
      mod = Module.new do
        class << self
          include Cattri
          cattri :version, "0.1.0", final: true, scope: :class
        end
      end

      expect(mod.version).to eq("0.1.0"), "Expected module singleton_class to retain class-level attribute value"
    end

    it "isolates class attributes across subclasses" do
      parent = Class.new do
        include Cattri
        cattri :level, "parent", scope: :class
      end

      child = Class.new(parent)
      expect(child.level).to eq("parent")

      child.level = "child"

      expect(parent.level).to eq("parent")
      expect(child.level).to eq("child")
    end

    it "applies custom coercion via block during assignment" do
      klass = Class.new do
        include Cattri
        cattri :age do |value|
          Integer(value)
        end
      end

      instance = klass.new
      instance.age = "42"

      expect(instance.age).to eq(42)
    end

    it "allows inherited initialize to set final attribute once" do
      base = Class.new do
        include Cattri
        cattri :token, final: true

        def initialize(token)
          self.token = token
        end
      end

      subclass = Class.new(base)
      obj = subclass.new("abc123")

      expect(obj.token).to eq("abc123")
      expect { obj.token = "fail" }.to raise_error(Cattri::AttributeError)
    end
  end
end
