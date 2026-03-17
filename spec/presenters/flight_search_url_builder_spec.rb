# frozen_string_literal: true

require "spec_helper"
require_relative "../../app/presenters/flight_search_url_builder"

RSpec.describe FlightSearchUrlBuilder do
  let(:origin)         { "BCN" }
  let(:destination)    { "LHR" }
  let(:departure_date) { Date.new(2025, 5, 1) }
  let(:return_date)    { Date.new(2025, 5, 8) }

  subject(:urls) do
    described_class.call(
      origin:         origin,
      destination:    destination,
      departure_date: departure_date,
      return_date:    return_date
    )
  end

  describe "#skyscanner_url" do
    it "builds the full Skyscanner search URL with YYMMDD dates" do
      expect(urls.skyscanner_url).to eq(
        "https://www.skyscanner.com/transport/flights/BCN/LHR/250501/250508/?adults=1&cabinclass=economy"
      )
    end

    it "upcases IATA codes" do
      result = described_class.call(
        origin: "bcn", destination: "lhr",
        departure_date: departure_date, return_date: return_date
      )
      expect(result.skyscanner_url).to include("/BCN/LHR/")
    end
  end

  describe "#google_flights_url" do
    it "builds the full Google Flights search URL" do
      expect(urls.google_flights_url).to eq(
        "https://www.google.com/flights/#search;f=BCN;t=LHR;d=2025-05-01;r=2025-05-08"
      )
    end

    it "upcases IATA codes" do
      result = described_class.call(
        origin: "bcn", destination: "lhr",
        departure_date: departure_date, return_date: return_date
      )
      expect(result.google_flights_url).to include("f=BCN")
      expect(result.google_flights_url).to include("t=LHR")
    end
  end

  describe "return value" do
    it "returns a FlightSearchUrls struct" do
      expect(urls).to be_a(FlightSearchUrls)
    end

    it "is frozen" do
      expect(urls).to be_frozen
    end
  end
end
