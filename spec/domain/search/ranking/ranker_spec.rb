# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Ranking::Ranker do
  def flight_sample(price_cents:, stops:)
    Search::Models::FlightSample.new(
      departure_datetime: Time.new(2025, 6, 1, 10, 0),
      return_datetime: Time.new(2025, 6, 8, 14, 0),
      luggage_included: true,
      price_cents: price_cents,
      stops: stops,
      air_time_minutes: 300,
      layover_time_minutes: 60
    )
  end

  def score_result(value)
    Search::Scoring::ScoreResult.new(value: value, components: { price: value, time_comfort: value, trip_fit: value })
  end

  describe ".call" do
    it "returns an array of RankedFlight" do
      flights = [ flight_sample(price_cents: 10_000, stops: 0) ]
      score_results = [ score_result(90.0) ]
      explanations = [ nil ]

      result = described_class.call(flights: flights, score_results: score_results, explanations: explanations)

      expect(result).to all(be_a(Search::Ranking::RankedFlight))
      expect(result.size).to eq(1)
      expect(result.first.rank).to eq(1)
    end

    it "sorts by final_score DESC, then price_cents ASC, then stops ASC" do
      low_score = flight_sample(price_cents: 20_000, stops: 1)
      high_score = flight_sample(price_cents: 15_000, stops: 0)
      flights = [ low_score, high_score ]
      score_results = [ score_result(70.0), score_result(90.0) ]
      explanations = [ nil, nil ]

      result = described_class.call(flights: flights, score_results: score_results, explanations: explanations)

      expect(result.size).to eq(2)
      expect(result[0].flight).to eq(high_score)
      expect(result[0].rank).to eq(1)
      expect(result[1].flight).to eq(low_score)
      expect(result[1].rank).to eq(2)
    end

    it "uses price_cents as tiebreaker when scores are equal" do
      cheaper = flight_sample(price_cents: 10_000, stops: 1)
      dearer = flight_sample(price_cents: 15_000, stops: 1)
      flights = [ dearer, cheaper ]
      score_results = [ score_result(80.0), score_result(80.0) ]
      explanations = [ nil, nil ]

      result = described_class.call(flights: flights, score_results: score_results, explanations: explanations)

      expect(result[0].flight).to eq(cheaper)
      expect(result[1].flight).to eq(dearer)
    end

    it "uses stops as second tiebreaker when score and price are equal" do
      fewer_stops = flight_sample(price_cents: 12_000, stops: 0)
      more_stops = flight_sample(price_cents: 12_000, stops: 1)
      flights = [ more_stops, fewer_stops ]
      score_results = [ score_result(75.0), score_result(75.0) ]
      explanations = [ nil, nil ]

      result = described_class.call(flights: flights, score_results: score_results, explanations: explanations)

      expect(result[0].flight).to eq(fewer_stops)
      expect(result[1].flight).to eq(more_stops)
    end

    it "includes entries with nil explanation" do
      fl = flight_sample(price_cents: 10_000, stops: 0)
      flights = [ fl ]
      score_results = [ score_result(85.0) ]
      explanations = [ nil ]

      result = described_class.call(flights: flights, score_results: score_results, explanations: explanations)

      expect(result.size).to eq(1)
      expect(result.first.explanation).to be_nil
      expect(result.first.flight).to eq(fl)
    end

    it "excludes triples where score_result is nil" do
      fl = flight_sample(price_cents: 10_000, stops: 0)
      flights = [ fl ]
      score_results = [ nil ]
      explanations = [ nil ]

      result = described_class.call(flights: flights, score_results: score_results, explanations: explanations)

      expect(result).to eq([])
    end

    it "returns empty array when all inputs are empty" do
      result = described_class.call(flights: [], score_results: [], explanations: [])

      expect(result).to eq([])
    end

    it "is deterministic for same inputs" do
      flights = [
        flight_sample(price_cents: 12_000, stops: 1),
        flight_sample(price_cents: 11_000, stops: 0)
      ]
      score_results = [ score_result(80.0), score_result(80.0) ]
      explanations = [ nil, nil ]

      result_a = described_class.call(flights: flights, score_results: score_results, explanations: explanations)
      result_b = described_class.call(flights: flights, score_results: score_results, explanations: explanations)

      expect(result_a.map(&:rank)).to eq(result_b.map(&:rank))
      expect(result_a.map { |r| r.flight.price_cents }).to eq(result_b.map { |r| r.flight.price_cents })
    end
  end
end
