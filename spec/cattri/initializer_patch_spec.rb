# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::InitializerPatch do
  let(:klass) do
    Class.new do
      include Cattri

      cattri :final_attr, -> { "default-final" }, final: true
      cattri :regular_attr, -> { "default-regular" }

      def initialize(preset: nil)
        self.final_attr = preset if preset
      end
    end
  end

  subject(:instance) { klass.new }

  describe "#initialize (via InitializerPatch)" do
    it "sets the default value for final attribute if unset" do
      expect(instance.final_attr).to eq("default-final")
    end

    it "does not override a final value if already set in initialize" do
      custom = klass.new(preset: "explicit")
      expect(custom.final_attr).to eq("explicit")
    end

    it "does not set default for non-final attributes" do
      expect(instance.cattri_variable_defined?(:regular_attr)).to be false
    end
  end
end
