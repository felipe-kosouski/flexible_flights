# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Factories::SearchRunFactory do
  let(:provider) { double("Provider") }

  let(:search_intent) do
    SearchIntent.new(
      origin_airport: "NYC",
      destination_airport: "LON",
      earliest_departure: Date.new(2025, 3, 1),
      latest_return: Date.new(2025, 3, 10),
      min_stay_days: 5,
      max_stay_days: 10,
      luggage_requirement: :carry_on,
      max_stops: 1,
      currency: "USD"
    )
  end

  let(:search_run_record) do
    SearchRun.new(
      search_intent: search_intent,
      state: :initialized,
      started_at: nil,
      finished_at: nil
    )
  end

  describe ".intent_from_record" do
    subject(:domain_intent) { described_class.intent_from_record(search_run_record) }

    it "reads currency from the search_intent record" do
      search_intent.currency = "BRL"
      expect(domain_intent.currency).to eq("BRL")
    end

    it "defaults to USD when the search_intent currency is USD" do
      search_intent.currency = "USD"
      expect(domain_intent.currency).to eq("USD")
    end
  end

  describe ".from_record" do
    subject(:domain_run) do
      described_class.from_record(
        search_run_record,
        max_candidates: 30,
        passengers: 2,
        cabin_class: :economy,
        provider: provider
      )
    end

    it "returns a Search::SearchRun domain object" do
      expect(domain_run).to be_a(Search::SearchRun)
    end

    it "copies route parameters from search intent" do
      expect(domain_run.instance_variable_get(:@origin)).to eq("NYC")
      expect(domain_run.instance_variable_get(:@destination)).to eq("LON")
    end

    it "copies date constraints from search intent" do
      expect(domain_run.instance_variable_get(:@earliest_departure_date)).to eq(Date.new(2025, 3, 1))
      expect(domain_run.instance_variable_get(:@latest_departure_date)).to eq(Date.new(2025, 3, 10))
    end

    it "copies stay constraints from search intent" do
      expect(domain_run.instance_variable_get(:@min_stay_days)).to eq(5)
      expect(domain_run.instance_variable_get(:@max_stay_days)).to eq(10)
    end

    it "injects execution parameters" do
      expect(domain_run.instance_variable_get(:@max_candidates)).to eq(30)
      expect(domain_run.instance_variable_get(:@passengers)).to eq(2)
      expect(domain_run.instance_variable_get(:@cabin_class)).to eq(:economy)
      expect(domain_run.instance_variable_get(:@provider)).to eq(provider)
    end

    it "does not mutate domain-relevant fields on the ActiveRecord object" do
      before_attributes = search_run_record.attributes.slice(
        "state",
        "started_at",
        "finished_at",
        "search_intent_id"
      )

      described_class.from_record(
        search_run_record,
        max_candidates: 30,
        passengers: 2,
        cabin_class: :economy,
        provider: provider
      )

      after_attributes = search_run_record.attributes.slice(
        "state",
        "started_at",
        "finished_at",
        "search_intent_id"
      )

      expect(after_attributes).to eq(before_attributes)
    end

    it "does not persist the domain object" do
      expect(search_run_record).not_to be_persisted
    end
  end
end
