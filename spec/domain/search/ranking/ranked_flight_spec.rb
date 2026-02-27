# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Ranking::RankedFlight do
  let(:flight) { instance_double(Search::Models::FlightSample) }
  let(:score_result) { instance_double(Search::Scoring::ScoreResult, value: 85.0) }
  let(:explanation) { instance_double(Search::Explanation::FlightExplanation) }

  subject(:ranked_flight) do
    described_class.new(
      flight: flight,
      score_result: score_result,
      explanation: explanation,
      rank: 1
    )
  end

  describe "construction" do
    it "exposes flight, score_result, explanation, and rank" do
      expect(ranked_flight.flight).to eq(flight)
      expect(ranked_flight.score_result).to eq(score_result)
      expect(ranked_flight.explanation).to eq(explanation)
      expect(ranked_flight.rank).to eq(1)
    end

    it "allows nil explanation" do
      rf = described_class.new(flight: flight, score_result: score_result, explanation: nil, rank: 2)
      expect(rf.explanation).to be_nil
      expect(rf.rank).to eq(2)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(ranked_flight).to be_frozen
    end
  end
end
