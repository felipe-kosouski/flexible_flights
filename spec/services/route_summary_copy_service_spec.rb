# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteSummaryCopyService do
  let(:wait_or_book) do
    instance_double(
      Search::Insights::WaitOrBookInsight,
      directive: :book_now,
      price_band: :cheap,
      top_flight_median_price_cents: 45000
    )
  end

  let(:price_rarity) do
    instance_double(
      Search::Insights::PriceRarityInsight,
      classification: :rare_cheap
    )
  end

  let(:insights) do
    instance_double(
      Search::Insights::SearchInsights,
      wait_or_book: wait_or_book,
      price_rarity: price_rarity
    )
  end

  let(:snapshot) do
    instance_double(
      Search::Models::AnalysisSnapshot,
      confidence: :high,
      sample_count: 50,
      price_p50_cents: 55000,
      price_p25_cents: 45000,
      price_p75_cents: 70000,
      volatility: :medium,
      price_distribution_present?: true
    )
  end

  let(:intent) do
    instance_double(SearchIntent, currency: "USD")
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
        double("Message", content: [double("Block", type: :text, text: "Bom texto")], )
      end

      described_class.call(insights: insights, snapshot: snapshot, intent: intent, locale: "pt-BR")
    end

    it "omits language instruction for en" do
      client = instance_double(Anthropic::Client)
      messages_double = instance_double(Anthropic::Resources::Messages)
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_return(messages_double)
      allow(messages_double).to receive(:create) do |params|
        expect(params[:system]).not_to include("Respond in")
        double("Message", content: [double("Block", type: :text, text: "Good text")])
      end

      described_class.call(insights: insights, snapshot: snapshot, intent: intent, locale: "en")
    end

    it "produces different cache keys for en and pt-BR" do
      en_service = described_class.new(insights, snapshot, intent, "en")
      pt_service = described_class.new(insights, snapshot, intent, "pt-BR")
      expect(en_service.send(:cache_key)).not_to eq(pt_service.send(:cache_key))
    end
  end
end
