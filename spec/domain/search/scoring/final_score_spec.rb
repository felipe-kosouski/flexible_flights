# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Scoring::FinalScore do
  subject(:result) do
    described_class.new(
      flight: flight_sample,
      intent: search_intent,
      snapshot: analysis_snapshot
    ).call
  end

  let(:flight_sample) { instance_double("Search::Models::FlightSample") }
  let(:search_intent) { instance_double("Search::Models::SearchIntent") }
  let(:analysis_snapshot) { instance_double("Search::Models::AnalysisSnapshot") }

  before do
    allow(Search::Scoring::PriceScore)
      .to receive(:call).and_return(price_score)

    allow(Search::Scoring::TimeComfortScore)
      .to receive(:call).and_return(time_score)

    allow(Search::Scoring::TripFit)
      .to receive(:call).and_return(trip_fit_score)
  end

  context "when all scores are present" do
    let(:price_score) { 100 }
    let(:time_score) { 80 }
    let(:trip_fit_score) { 90 }

    it "returns a ScoreResult" do
      expect(result).to be_a(Search::Scoring::ScoreResult)
    end

    it "has the weighted average as value" do
      expected = (100 * 0.45) + (80 * 0.35) + (90 * 0.20)

      expect(result.value).to eq(expected)
    end

    it "exposes component scores" do
      expect(result.components).to eq(price: 100, time_comfort: 80, trip_fit: 90)
    end

    it "freezes the result" do
      expect(result).to be_frozen
    end

    it "freezes the components hash" do
      expect(result.components).to be_frozen
    end
  end

  context "when one scorer returns nil" do
    let(:price_score) { nil }
    let(:time_score) { 80 }
    let(:trip_fit_score) { 90 }

    it "returns a ScoreResult" do
      expect(result).to be_a(Search::Scoring::ScoreResult)
    end

    it "renormalizes weights in value" do
      total_weight = 0.35 + 0.20

      expected = (80 * (0.35 / total_weight)) + (90 * (0.20 / total_weight))

      expect(result.value).to eq(expected)
    end

    it "only includes non-nil components" do
      expect(result.components).to eq(time_comfort: 80, trip_fit: 90)
    end
  end

  context "when all scorers return nil" do
    let(:price_score) { nil }
    let(:time_score) { nil }
    let(:trip_fit_score) { nil }

    it "returns nil" do
      expect(result).to be_nil
    end
  end
end
