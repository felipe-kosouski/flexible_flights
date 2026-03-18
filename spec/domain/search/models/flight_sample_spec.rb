# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../app/domain/search/models/flight_sample"

RSpec.describe Search::Models::FlightSample do
  let(:departure_datetime) { Time.new(2025, 3, 1, 10, 0, 0) }
  let(:return_datetime) { Time.new(2025, 3, 8, 14, 0, 0) }

  describe "#currency" do
    it "stores and returns the currency" do
      sample = described_class.new(
        departure_datetime: departure_datetime,
        return_datetime: return_datetime,
        luggage_included: false,
        currency: "BRL"
      )
      expect(sample.currency).to eq("BRL")
    end

    it "defaults to USD" do
      sample = described_class.new(
        departure_datetime: departure_datetime,
        return_datetime: return_datetime,
        luggage_included: false
      )
      expect(sample.currency).to eq("USD")
    end
  end
end
