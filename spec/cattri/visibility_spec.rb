# frozen_string_literal: true

require "spec_helper"
require "cattri/visibility"

RSpec.describe Cattri::Visibility do
  let(:klass) do
    Class.new do
      extend Cattri::Visibility

      def self.visibility_value
        __cattri_visibility
      end
    end
  end

  describe "#__cattri_visibility" do
    it "defaults to public" do
      expect(klass.visibility_value).to eq(:public)
    end
  end

  describe "#public" do
    it "sets visibility to public when no args are passed" do
      klass.protected
      klass.public

      expect(klass.visibility_value).to eq(:public)
    end

    it "delegates to Module#public when args are passed" do
      klass.class_eval do
        def sample_method; end
        private :sample_method
      end

      expect { klass.public :sample_method }.not_to raise_error
      expect(klass.public_instance_methods).to include(:sample_method)
    end
  end

  describe "#protected" do
    it "sets visibility to protected when no args are passed" do
      klass.protected
      expect(klass.visibility_value).to eq(:protected)
    end

    it "delegates to Module#protected when args are passed" do
      klass.class_eval do
        def protected_method; end
      end

      expect { klass.protected :protected_method }.not_to raise_error
      expect(klass.protected_instance_methods).to include(:protected_method)
    end
  end

  describe "#private" do
    it "sets visibility to private when no args are passed" do
      klass.private
      expect(klass.visibility_value).to eq(:private)
    end

    it "delegates to Module#private when args are passed" do
      klass.class_eval do
        def private_method; end
      end

      expect { klass.private :private_method }.not_to raise_error
      expect(klass.private_instance_methods).to include(:private_method)
    end
  end
end
