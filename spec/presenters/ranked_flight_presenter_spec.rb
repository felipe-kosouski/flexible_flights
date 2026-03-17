# frozen_string_literal: true

require "rails_helper"

RSpec.describe RankedFlightPresenter do
  let(:departure_dt) { Time.zone.local(2025, 5, 1, 10, 0) }
  let(:return_dt)    { Time.zone.local(2025, 5, 8, 18, 0) }

  let(:flight) do
    instance_double(
      Search::Models::FlightSample,
      departure_datetime:    departure_dt,
      return_datetime:       return_dt,
      price_cents:           15000,
      stops:                 0,
      air_time_minutes:      120,
      layover_time_minutes:  0,
      luggage_included?:     false,
      stay_length_days:      7
    )
  end

  let(:score_result) do
    instance_double(
      Search::Scoring::ScoreResult,
      value: 82.0,
      components: { price: 80.0, time_comfort: 85.0, trip_fit: 80.0 }
    )
  end

  let(:ranked_flight) do
    instance_double(
      Search::Ranking::RankedFlight,
      rank:         1,
      flight:       flight,
      score_result: score_result,
      explanation:  nil
    )
  end

  let(:intent) do
    instance_double(
      SearchIntent,
      origin_airport:      "BCN",
      destination_airport: "LHR"
    )
  end

  describe "#search_urls" do
    context "when intent is present" do
      subject(:presenter) { described_class.new(ranked_flight, intent: intent) }

      it "returns a FlightSearchUrls struct" do
        expect(presenter.search_urls).to be_a(FlightSearchUrls)
      end

      it "builds a Skyscanner URL with the flight dates" do
        expect(presenter.search_urls.skyscanner_url).to include("BCN/LHR/250501/250508")
      end

      it "builds a Google Flights URL with the flight dates" do
        expect(presenter.search_urls.google_flights_url).to include("f=BCN;t=LHR;d=2025-05-01")
      end
    end

    context "when intent is absent" do
      subject(:presenter) { described_class.new(ranked_flight) }

      it "returns nil" do
        expect(presenter.search_urls).to be_nil
      end
    end
  end
end
