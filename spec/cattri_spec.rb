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
end
