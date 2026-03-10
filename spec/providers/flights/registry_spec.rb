# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flights::Registry do
  describe ".resolve" do
    it "returns a Stub instance for 'stub'" do
      provider = described_class.resolve("stub")
      expect(provider).to be_a(Flights::Stub)
    end

    it "returns an Amadeus::Provider instance for 'amadeus'" do
      allow(ENV).to receive(:fetch).with("AMADEUS_CLIENT_ID").and_return("id")
      allow(ENV).to receive(:fetch).with("AMADEUS_CLIENT_SECRET").and_return("secret")
      allow(ENV).to receive(:fetch).with("AMADEUS_ENV", "test").and_return("test")

      provider = described_class.resolve("amadeus")
      expect(provider).to be_a(Flights::Amadeus::Provider)
    end

    it "raises ArgumentError for an unknown provider name" do
      expect { described_class.resolve("unknown") }.to raise_error(ArgumentError, /unknown/i)
    end
  end
end
