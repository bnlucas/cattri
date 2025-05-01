# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Error do
  describe ".new" do
    it "inherits from StandardError" do
      expect(described_class).to be < StandardError
    end

    it "sets the message and custom backtrace" do
      backtrace = ["custom/location.rb:42"]
      error = described_class.new("oops", backtrace)

      expect(error.message).to eq("oops")
      expect(error.backtrace).to eq(backtrace)
    end

    it "defaults to caller backtrace if none given" do
      error = described_class.new("default trace")
      expect(error.backtrace).to be_an(Array)
      expect(error.backtrace.first).to include(__FILE__)
    end
  end
end

RSpec.describe Cattri::AttributeError do
  it "inherits from Cattri::Error" do
    expect(described_class).to be < Cattri::Error
  end

  it "retains message and backtrace" do
    error = described_class.new("bad attr", ["attr.rb:1"])
    expect(error.message).to eq("bad attr")
    expect(error.backtrace).to eq(["attr.rb:1"])
  end
end
