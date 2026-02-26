# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Scoring::Scorer do
  let(:flight)   { instance_double("Search::Models::FlightSample") }
  let(:intent)   { instance_double("Search::Models::SearchIntent") }
  let(:snapshot) { instance_double("Search::Models::AnalysisSnapshot") }
  let(:final_score_result) { 72.5 }

  subject(:scorer) { described_class.new(flight: flight, intent: intent, snapshot: snapshot) }

  before do
    final_score_instance = instance_double(Search::Scoring::FinalScore, call: final_score_result)
    allow(Search::Scoring::FinalScore)
      .to receive(:new)
      .with(flight: flight, intent: intent, snapshot: snapshot)
      .and_return(final_score_instance)
  end

  describe "#call" do
    it "delegates to FinalScore and returns its result" do
      expect(scorer.call).to eq(final_score_result)
    end

    it "passes nil through when FinalScore returns nil" do
      allow(Search::Scoring::FinalScore)
        .to receive(:new)
        .and_return(instance_double(Search::Scoring::FinalScore, call: nil))

      expect(scorer.call).to be_nil
    end
  end
end
