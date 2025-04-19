# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cattri::Error do
  it "raises a Cattri::Error" do
    expect { raise Cattri::Error, "test" }.to raise_error(Cattri::Error, "test")
  end
end
