# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Introspection do
  let(:test_class) do
    Class.new do
      include Cattri::Introspection
    end
  end

  let(:attrs_class) do
    Class.new(test_class) do
      include Cattri

      cattr :c_test, default: "default"
      iattr :i_test, default: "default"
      iattr_writer :i_write_only
    end
  end

  describe ".snapshot_class_attributes" do
    subject { attrs_class }

    it "returns an empty hash when Cattri::ClassAttributes is not extended" do
      expect(test_class.snapshot_class_attributes).to eq({})
    end

    it "returns the current snapshot of class attribute values" do
      expect(subject.snapshot_class_attributes).to eq({ c_test: "default" })

      subject.c_test = "updated"
      expect(subject.snapshot_class_attributes).to eq({ c_test: "updated" })
    end

    it "has the snapshot_cattrs alias" do
      expect(subject.method(:snapshot_cattrs)).to eq(subject.method(:snapshot_class_attributes))
    end
  end

  describe "#snapshot_instance_attributes" do
    subject { attrs_class.new }

    it "returns an empty hash when Cattri::InstanceAttributes is not included" do
      expect(test_class.new.snapshot_instance_attributes).to eq({})
    end

    it "returns the current snapshot of instance attribute values" do
      expect(subject.snapshot_instance_attributes).to eq({ i_test: "default", i_write_only: nil })

      subject.i_test = "updated"
      subject.i_write_only = "updated"
      expect(subject.snapshot_instance_attributes).to eq({ i_test: "updated", i_write_only: "updated" })
    end

    it "has the snapshot_iattrs alias" do
      expect(subject.method(:snapshot_iattrs)).to eq(subject.method(:snapshot_instance_attributes))
    end
  end
end
