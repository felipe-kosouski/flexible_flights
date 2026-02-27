# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Scoring::FinalScore do
  subject(:score) do
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

    it "returns weighted average" do
      expected = (100 * 0.45) + (80 * 0.35) + (90 * 0.20)

      expect(score).to eq(expected)
    end
  end

  context "when one scorer returns nil" do
    let(:price_score) { nil }
    let(:time_score) { 80 }
    let(:trip_fit_score) { 90 }

    it "renormalizes weights" do
      total_weight = 0.35 + 0.20

      expected = (80 * (0.35 / total_weight)) + (90 * (0.20 / total_weight))

      expect(score).to eq(expected)
    end
  end

  context "when all scorers return nil" do
    let(:price_score) { nil }
    let(:time_score) { nil }
    let(:trip_fit_score) { nil }

    it "returns nil" do
      expect(score).to be_nil
    end
  end
end
