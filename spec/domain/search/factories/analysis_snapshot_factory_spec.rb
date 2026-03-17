# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Factories::AnalysisSnapshotFactory do
  describe ".from_record" do
    let(:ar_record) do
      # Simulate the AR AnalysisSnapshot interface without touching the DB.
      # AR integer enums return the string key (e.g. "low"), not the integer.
      double(
        "AnalysisSnapshot",
        price_p25_cents: 5_000,
        price_p50_cents: 8_000,
        price_p75_cents: 12_000,
        route_median_duration_minutes: 180,
        sample_count: 25,
        confidence_level: "medium",
        volatility: "high"
      )
    end

    subject(:snapshot) { described_class.from_record(ar_record) }

    it "returns a Models::AnalysisSnapshot" do
      expect(snapshot).to be_a(Search::Models::AnalysisSnapshot)
    end

    it "maps price percentiles" do
      expect(snapshot.price_p25_cents).to eq(5_000)
      expect(snapshot.price_p50_cents).to eq(8_000)
      expect(snapshot.price_p75_cents).to eq(12_000)
    end

    it "maps route_median_duration_minutes" do
      expect(snapshot.route_median_duration_minutes).to eq(180)
    end

    it "maps sample_count" do
      expect(snapshot.sample_count).to eq(25)
    end

    it "converts confidence_level string to symbol" do
      expect(snapshot.confidence).to eq(:medium)
    end

    it "converts volatility string to symbol" do
      expect(snapshot.volatility).to eq(:high)
    end

    context "when record is nil" do
      it "returns nil" do
        expect(described_class.from_record(nil)).to be_nil
      end
    end
  end
end
