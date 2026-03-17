# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Scoring::Scorer do
  let(:flight) { instance_double("Search::Models::FlightSample") }
  let(:intent) { instance_double("Search::Models::SearchIntent") }
  let(:snapshot) { instance_double("Search::Models::AnalysisSnapshot") }

  let(:score_result) do
    Search::Scoring::ScoreResult.new(
      value: 72.5,
      components: { price: 80, time_comfort: 60, trip_fit: 75 }
    )
  end

  subject(:scorer) { described_class.new(flight: flight, intent: intent, snapshot: snapshot) }

  before do
    final_score_instance = instance_double(Search::Scoring::FinalScore, call: score_result)
    allow(Search::Scoring::FinalScore)
      .to receive(:new)
      .with(flight: flight, intent: intent, snapshot: snapshot)
      .and_return(final_score_instance)
  end

  describe "#call" do
    it "returns a ScoreResult" do
      expect(scorer.call).to be_a(Search::Scoring::ScoreResult)
    end

    it "delegates to FinalScore and returns its result" do
      expect(scorer.call).to eq(score_result)
    end

    it "passes nil through when FinalScore returns nil" do
      allow(Search::Scoring::FinalScore)
        .to receive(:new)
        .and_return(instance_double(Search::Scoring::FinalScore, call: nil))

      expect(scorer.call).to be_nil
    end
  end
end
