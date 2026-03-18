# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../app/domain/search/models/flight_sample"
require_relative "../../../../app/domain/search/mappers/flight_sample_mapper"

RSpec.describe Search::Mappers::FlightSampleMapper do
  let(:departure_time) { Time.new(2025, 3, 1, 10, 0, 0) }
  let(:return_time) { Time.new(2025, 3, 8, 14, 0, 0) }

  let(:valid_hash) do
    {
      price_cents: 15_000,
      stops: 1,
      air_time_minutes: 300,
      layover_time_minutes: 60,
      departure_datetime: departure_time,
      return_datetime: return_time,
      luggage_included: true,
      currency: "USD",
      airline_codes: [ "AA" ],
      raw_provider: "test"
    }
  end

  describe ".from_hash" do
    it "returns a FlightSample domain object" do
      result = described_class.from_hash(valid_hash)

      expect(result).to be_a(Search::Models::FlightSample)
    end

    it "maps all scoring-relevant attributes" do
      result = described_class.from_hash(valid_hash)

      expect(result.price_cents).to eq(15_000)
      expect(result.stops).to eq(1)
      expect(result.air_time_minutes).to eq(300)
      expect(result.layover_time_minutes).to eq(60)
      expect(result.luggage_included?).to be true
    end

    it "maps datetime attributes" do
      result = described_class.from_hash(valid_hash)

      expect(result.stay_length_days).to eq(7)
      expect(result.has_times?).to be_truthy
    end

    it "maps currency from the raw sample" do
      hash_brl = valid_hash.merge(currency: "BRL")
      mapped = described_class.from_hash(hash_brl)
      expect(mapped.currency).to eq("BRL")
    end

    it "returns nil for non-hash input" do
      expect(described_class.from_hash("invalid")).to be_nil
      expect(described_class.from_hash(nil)).to be_nil
      expect(described_class.from_hash(42)).to be_nil
    end

    it "handles hashes with missing optional fields" do
      minimal = {
        departure_datetime: departure_time,
        return_datetime: return_time,
        luggage_included: false
      }

      result = described_class.from_hash(minimal)

      expect(result).to be_a(Search::Models::FlightSample)
      expect(result.price_cents).to be_nil
      expect(result.stops).to be_nil
      expect(result.luggage_included?).to be false
    end
  end

  describe ".map_all" do
    it "converts an array of hashes to FlightSample objects" do
      results = described_class.map_all([ valid_hash, valid_hash ])

      expect(results.size).to eq(2)
      expect(results).to all(be_a(Search::Models::FlightSample))
    end

    it "skips non-hash entries" do
      results = described_class.map_all([ valid_hash, "invalid", nil, valid_hash ])

      expect(results.size).to eq(2)
    end

    it "returns an empty array for empty input" do
      expect(described_class.map_all([])).to eq([])
    end

    it "preserves ordering" do
      hash_a = valid_hash.merge(price_cents: 100)
      hash_b = valid_hash.merge(price_cents: 200)

      results = described_class.map_all([ hash_a, hash_b ])

      expect(results.map(&:price_cents)).to eq([ 100, 200 ])
    end
  end
end
