# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Explanation::Builder do
  subject(:result) do
    described_class.call(
      flight: flight,
      intent: intent,
      snapshot: snapshot,
      final_score: final_score
    )
  end

  let(:flight) do
    Search::Models::FlightSample.new(
      departure_datetime: Time.new(2025, 6, 1, 10, 0),
      return_datetime: Time.new(2025, 6, 15, 14, 0),
      luggage_included: true,
      price_cents: 25_000,
      stops: 1,
      air_time_minutes: 300,
      layover_time_minutes: 200
    )
  end

  let(:intent) do
    Search::Models::SearchIntent.new(
      min_stay_days: 7,
      max_stay_days: 21,
      luggage_requirement: :optional
    )
  end

  let(:snapshot) do
    Search::Models::AnalysisSnapshot.new(
      price_p25_cents: 25_000,
      price_p50_cents: 50_000,
      price_p75_cents: 75_000,
      route_median_duration_minutes: 400,
      sample_count: 30,
      volatility: :medium,
      confidence: :high
    )
  end

  let(:final_score) do
    Search::Scoring::FinalScore.new(flight: flight, intent: intent, snapshot: snapshot)
  end

  let(:price_score_value) { 100 }
  let(:time_comfort_score_value) { 80 }
  let(:trip_fit_score_value) { 75 }

  before do
    allow(Search::Scoring::PriceScore)
      .to receive(:call).and_return(price_score_value)

    allow(Search::Scoring::TimeComfortScore)
      .to receive(:call).and_return(time_comfort_score_value)

    allow(Search::Scoring::TripFit)
      .to receive(:call).and_return(trip_fit_score_value)
  end

  describe "happy path" do
    it "returns a FlightExplanation" do
      expect(result).to be_a(Search::Explanation::FlightExplanation)
    end

    it "references the flight" do
      expect(result.flight).to eq(flight)
    end

    it "includes score_breakdown, tradeoffs, and summary" do
      expect(result.score_breakdown).to be_an(Array)
      expect(result.tradeoffs).to be_an(Array)
      expect(result.summary).to be_a(Hash)
    end
  end

  describe "score breakdown" do
    it "contains one entry per scoring dimension" do
      expect(result.score_breakdown.size).to eq(3)
    end

    it "includes all required fields in each entry" do
      required_keys = %i[dimension raw_score normalized_score weight weighted_contribution]

      result.score_breakdown.each do |entry|
        expect(entry.keys).to include(*required_keys)
      end
    end

    it "produces entries for each dimension" do
      dimensions = result.score_breakdown.map { |e| e[:dimension] }
      expect(dimensions).to contain_exactly(:price, :time_comfort, :trip_fit)
    end

    it "uses weights from FinalScore::WEIGHTS" do
      result.score_breakdown.each do |entry|
        expected_weight = Search::Scoring::FinalScore::WEIGHTS[entry[:dimension]]
        expect(entry[:weight]).to eq(expected_weight)
      end
    end

    it "computes weighted_contribution as normalized_score * weight" do
      result.score_breakdown.each do |entry|
        expect(entry[:weighted_contribution]).to eq(entry[:normalized_score] * entry[:weight])
      end
    end

    it "has a sum of weighted_contributions matching expected final score" do
      expected = (price_score_value * 0.45) +
                 (time_comfort_score_value * 0.35) +
                 (trip_fit_score_value * 0.20)

      actual_sum = result.score_breakdown.sum { |e| e[:weighted_contribution] }
      expect(actual_sum).to be_within(0.0001).of(expected)
    end

    it "orders entries deterministically" do
      dimensions_a = result.score_breakdown.map { |e| e[:dimension] }

      second_result = described_class.call(
        flight: flight, intent: intent, snapshot: snapshot, final_score: final_score
      )
      dimensions_b = second_result.score_breakdown.map { |e| e[:dimension] }

      expect(dimensions_a).to eq(dimensions_b)
    end

    it "does not include inferred or synthetic dimensions" do
      valid_dimensions = Search::Scoring::FinalScore::WEIGHTS.keys
      result.score_breakdown.each do |entry|
        expect(valid_dimensions).to include(entry[:dimension])
      end
    end
  end

  describe "summary" do
    it "is deterministic across calls" do
      summary_a = result.summary
      summary_b = described_class.call(
        flight: flight, intent: intent, snapshot: snapshot, final_score: final_score
      ).summary

      expect(summary_a).to eq(summary_b)
    end

    it "includes primary_factors, secondary_factors, and explanation_keys" do
      expect(result.summary).to include(:primary_factors, :secondary_factors, :explanation_keys)
    end

    it "references the dominant dimension as primary factor" do
      expect(result.summary[:primary_factors]).to include(:price)
    end

    it "does not include primary factors in secondary factors" do
      primary = result.summary[:primary_factors]
      secondary = result.summary[:secondary_factors]
      expect(primary & secondary).to be_empty
    end

    it "derives explanation_keys from predefined symbols" do
      all_valid_keys = Search::Explanation::Builder::DIMENSION_STRENGTH_KEYS.values +
                       Search::Explanation::Builder::TRADEOFF_KEYS.values

      result.summary[:explanation_keys].each do |key|
        expect(all_valid_keys).to include(key)
      end
    end
  end

  describe "tradeoff detection" do
    context "when price is materially above baseline and duration materially below" do
      let(:flight) do
        Search::Models::FlightSample.new(
          departure_datetime: Time.new(2025, 6, 1, 10, 0),
          return_datetime: Time.new(2025, 6, 15, 14, 0),
          luggage_included: true,
          price_cents: 25_000,
          stops: 1,
          air_time_minutes: 300,
          layover_time_minutes: 200
        )
      end

      it "emits at least one tradeoff" do
        expect(result.tradeoffs).not_to be_empty
      end

      it "includes all required tradeoff fields" do
        required_keys = %i[gained_dimension sacrificed_dimension severity explanation_key]

        result.tradeoffs.each do |tradeoff|
          expect(tradeoff.keys).to include(*required_keys)
        end
      end

      it "identifies price as gained and time_comfort as sacrificed" do
        tradeoff = result.tradeoffs.find { |t| t[:gained_dimension] == :price }
        expect(tradeoff).not_to be_nil
        expect(tradeoff[:sacrificed_dimension]).to eq(:time_comfort)
      end

      it "assigns the correct explanation key" do
        tradeoff = result.tradeoffs.find { |t| t[:gained_dimension] == :price }
        expect(tradeoff[:explanation_key]).to eq(:cheap_but_longer)
      end
    end

    context "when all dimensions are near baseline" do
      let(:flight) do
        Search::Models::FlightSample.new(
          departure_datetime: Time.new(2025, 6, 1, 10, 0),
          return_datetime: Time.new(2025, 6, 15, 14, 0),
          luggage_included: true,
          price_cents: 49_000,
          stops: 1,
          air_time_minutes: 280,
          layover_time_minutes: 85
        )
      end

      it "returns empty tradeoffs" do
        expect(result.tradeoffs).to be_empty
      end
    end

    context "tradeoff severity" do
      context "when both deviations are strong" do
        let(:flight) do
          Search::Models::FlightSample.new(
            departure_datetime: Time.new(2025, 6, 1, 10, 0),
            return_datetime: Time.new(2025, 6, 15, 14, 0),
            luggage_included: true,
            price_cents: 25_000,
            stops: 1,
            air_time_minutes: 400,
            layover_time_minutes: 200
          )
        end

        it "assigns :high severity" do
          tradeoff = result.tradeoffs.find { |t| t[:gained_dimension] == :price }
          expect(tradeoff[:severity]).to eq(:high)
        end
      end

      context "when one deviation is strong and other moderate" do
        let(:flight) do
          Search::Models::FlightSample.new(
            departure_datetime: Time.new(2025, 6, 1, 10, 0),
            return_datetime: Time.new(2025, 6, 15, 14, 0),
            luggage_included: true,
            price_cents: 30_000,
            stops: 1,
            air_time_minutes: 350,
            layover_time_minutes: 100
          )
        end

        it "assigns :medium severity" do
          tradeoff = result.tradeoffs.find { |t| t[:gained_dimension] == :price }
          expect(tradeoff[:severity]).to eq(:medium)
        end
      end

      context "when both deviations are moderate" do
        let(:flight) do
          Search::Models::FlightSample.new(
            departure_datetime: Time.new(2025, 6, 1, 10, 0),
            return_datetime: Time.new(2025, 6, 15, 14, 0),
            luggage_included: true,
            price_cents: 38_000,
            stops: 1,
            air_time_minutes: 350,
            layover_time_minutes: 100
          )
        end

        it "assigns :low severity" do
          tradeoff = result.tradeoffs.find { |t| t[:gained_dimension] == :price }
          expect(tradeoff[:severity]).to eq(:low)
        end
      end

      it "is deterministic" do
        severity_a = result.tradeoffs.map { |t| t[:severity] }
        severity_b = described_class.call(
          flight: flight, intent: intent, snapshot: snapshot, final_score: final_score
        ).tradeoffs.map { |t| t[:severity] }

        expect(severity_a).to eq(severity_b)
      end
    end
  end

  describe "baseline handling" do
    context "when price baseline is missing" do
      let(:snapshot) do
        Search::Models::AnalysisSnapshot.new(
          price_p25_cents: nil,
          price_p50_cents: nil,
          price_p75_cents: nil,
          route_median_duration_minutes: 400,
          sample_count: 30,
          volatility: :medium,
          confidence: :high
        )
      end

      it "still returns an explanation" do
        expect(result).to be_a(Search::Explanation::FlightExplanation)
      end

      it "degrades tradeoff detection gracefully" do
        expect(result.tradeoffs).to be_an(Array)
        expect { result }.not_to raise_error
      end
    end

    context "when duration baseline is missing" do
      let(:snapshot) do
        Search::Models::AnalysisSnapshot.new(
          price_p25_cents: 25_000,
          price_p50_cents: 50_000,
          price_p75_cents: 75_000,
          route_median_duration_minutes: nil,
          sample_count: 30,
          volatility: :medium,
          confidence: :high
        )
      end

      it "still returns an explanation" do
        expect(result).to be_a(Search::Explanation::FlightExplanation)
      end

      it "degrades tradeoff detection gracefully" do
        expect(result.tradeoffs).to be_an(Array)
        expect { result }.not_to raise_error
      end
    end

    context "when all baselines are missing" do
      let(:snapshot) do
        Search::Models::AnalysisSnapshot.new(
          price_p25_cents: nil,
          price_p50_cents: nil,
          price_p75_cents: nil,
          route_median_duration_minutes: nil,
          sample_count: nil,
          volatility: nil,
          confidence: nil
        )
      end

      it "returns empty tradeoffs" do
        expect(result.tradeoffs).to be_empty
      end
    end
  end

  describe "failure semantics" do
    context "when final_score is nil" do
      let(:final_score) { nil }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when a component score is missing" do
      let(:price_score_value) { nil }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when all component scores are missing" do
      let(:price_score_value) { nil }
      let(:time_comfort_score_value) { nil }
      let(:trip_fit_score_value) { nil }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    it "never raises for nil final_score" do
      expect {
        described_class.call(flight: flight, intent: intent, snapshot: snapshot, final_score: nil)
      }.not_to raise_error
    end

    it "never raises for nil flight" do
      expect {
        described_class.call(flight: nil, intent: intent, snapshot: snapshot, final_score: final_score)
      }.not_to raise_error
    end

    it "never raises for nil snapshot" do
      expect {
        described_class.call(flight: flight, intent: intent, snapshot: nil, final_score: final_score)
      }.not_to raise_error
    end
  end

  describe "determinism" do
    it "produces identical output for identical inputs" do
      result_a = described_class.call(
        flight: flight, intent: intent, snapshot: snapshot, final_score: final_score
      )
      result_b = described_class.call(
        flight: flight, intent: intent, snapshot: snapshot, final_score: final_score
      )

      expect(result_a.score_breakdown).to eq(result_b.score_breakdown)
      expect(result_a.tradeoffs).to eq(result_b.tradeoffs)
      expect(result_a.summary).to eq(result_b.summary)
    end
  end

  describe "immutability" do
    it "freezes the FlightExplanation" do
      expect(result).to be_frozen
    end

    it "freezes score_breakdown" do
      expect(result.score_breakdown).to be_frozen
    end

    it "freezes each score_breakdown entry" do
      result.score_breakdown.each do |entry|
        expect(entry).to be_frozen
      end
    end

    it "freezes tradeoffs" do
      expect(result.tradeoffs).to be_frozen
    end

    it "freezes summary" do
      expect(result.summary).to be_frozen
    end

    it "does not mutate the flight input" do
      original_price = flight.price_cents
      result
      expect(flight.price_cents).to eq(original_price)
    end

    it "does not mutate the snapshot input" do
      original_median = snapshot.price_p50_cents
      result
      expect(snapshot.price_p50_cents).to eq(original_median)
    end
  end
end
