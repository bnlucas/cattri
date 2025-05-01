# frozen_string_literal: true

RSpec.describe Cattri::Dsl do
  let(:registry) { instance_double(Cattri::AttributeRegistry) }

  let(:klass) do
    Class.new do
      extend Cattri::Dsl

      def self.__cattri_visibility
        :protected
      end
    end
  end

  before do
    allow(klass).to receive(:attribute_registry).and_return(registry)
  end

  describe ".cattri" do
    it "delegates to attribute_registry.define_attribute with merged visibility" do
      expect(registry).to receive(:define_attribute)
        .with(:foo, 123, visibility: :protected)

      klass.cattri(:foo, 123)
    end

    it "merges user-provided options with current visibility" do
      expect(registry).to receive(:define_attribute)
        .with(:bar, nil, visibility: :protected, final: true)

      klass.cattri(:bar, nil, final: true)
    end

    it "passes through block if provided" do
      expect(registry).to receive(:define_attribute) do |name, value, **opts, &blk|
        expect(name).to eq(:lazy)
        expect(value).to be_nil
        expect(opts[:visibility]).to eq(:protected)
        expect(blk.call).to eq(:computed)
      end

      klass.cattri(:lazy) { :computed }
    end
  end

  describe ".final_cattri" do
    it "calls cattri with final: true merged into options" do
      expect(klass).to receive(:cattri)
        .with(:token, "xyz", hash_including(final: true))

      klass.final_cattri(:token, "xyz")
    end

    it "respects additional options" do
      expect(klass).to receive(:cattri)
        .with(:token, "xyz", hash_including(scope: :class, final: true))

      klass.final_cattri(:token, "xyz", scope: :class)
    end

    it "passes block through to cattri" do
      block = proc { "lazy!" }
      expect(klass).to receive(:cattri).with(:val, nil, hash_including(final: true), &block)

      klass.final_cattri(:val, nil, &block)
    end
  end
end
