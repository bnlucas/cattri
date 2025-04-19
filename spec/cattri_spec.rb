# frozen_string_literal: true

RSpec.describe Cattri do
  let(:klass) do
    Class.new do
      include Cattri
    end
  end

  it "extends class with ClassAttributes" do
    expect(klass.singleton_class.included_modules).to include(Cattri::ClassAttributes)
  end

  it "includes InstanceAttributes" do
    expect(klass.included_modules).to include(Cattri::InstanceAttributes)
  end
end
