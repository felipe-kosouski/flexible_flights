# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExplanationCopyService do
  let(:departure_dt) { Time.zone.local(2025, 5, 1, 10, 0) }
  let(:return_dt) { Time.zone.local(2025, 5, 8, 18, 0) }

  let(:flight) do
    instance_double(
      Search::Models::FlightSample,
      departure_datetime: departure_dt,
      return_datetime: return_dt,
      price_cents: 50000,
      stops: 0,
      air_time_minutes: 120,
      layover_time_minutes: 0,
      luggage_included?: false,
      currency: "USD"
    )
  end

  let(:score_result) do
    instance_double(
      Search::Scoring::ScoreResult,
      value: 75.0,
      components: { price: 70.0, time_comfort: 80.0, trip_fit: 75.0 }
    )
  end

  let(:baselines) do
    {
      price_median_cents: 55000,
      volatility: "medium",
      duration_median_minutes: 120
    }
  end

  let(:score_breakdown) do
    [
      { dimension: :price, relative_to_baseline: :better },
      { dimension: :time_comfort, relative_to_baseline: :neutral }
    ]
  end

  let(:explanation) do
    instance_double(
      Search::Explanation::FlightExplanation,
      baselines: baselines,
      score_breakdown: score_breakdown
    )
  end

  let(:ranked_flight) do
    instance_double(
      Search::Ranking::RankedFlight,
      rank: 1,
      flight: flight,
      score_result: score_result,
      explanation: explanation
    )
  end

  let(:intent) do
    instance_double(
      SearchIntent,
      max_stops: 1,
      luggage_requirement: "carry_on"
    )
  end

  describe "locale support" do
    before do
      allow(Rails.application.credentials).to receive(:anthropic_api_key).and_return("test-key")
      allow(Rails.cache).to receive(:fetch).and_yield
    end

    it "includes PT-BR language instruction in system prompt" do
      client = instance_double(Anthropic::Client)
      messages_double = instance_double(Anthropic::Resources::Messages)
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_return(messages_double)
      allow(messages_double).to receive(:create) do |params|
        expect(params[:system]).to include("Respond in Brazilian Portuguese (PT-BR).")
        double("Message", content: [])
      end

      described_class.call(ranked_flight: ranked_flight, intent: intent, locale: "pt-BR")
    end

    it "omits language instruction for en" do
      client = instance_double(Anthropic::Client)
      messages_double = instance_double(Anthropic::Resources::Messages)
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_return(messages_double)
      allow(messages_double).to receive(:create) do |params|
        expect(params[:system]).not_to include("Respond in")
        double("Message", content: [])
      end

      described_class.call(ranked_flight: ranked_flight, intent: intent, locale: "en")
    end

    it "produces different fingerprints for en and pt-BR" do
      en_fp = described_class.fingerprint_for(ranked_flight, locale: "en")
      pt_fp = described_class.fingerprint_for(ranked_flight, locale: "pt-BR")
      expect(en_fp).not_to eq(pt_fp)
    end
  end
end
