# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Scoring::PriceScore do
  let(:analysis_snapshot) do
    Search::Models::AnalysisSnapshot.new(
      price_p25_cents: 10_000,
      price_p50_cents: 20_000,
      price_p75_cents: 30_000
    )
  end

  let(:price_cents) { 10_000 }

  let(:flight_sample) do
    Search::Models::FlightSample.new(
      departure_datetime: Time.new(2025, 3, 1, 10, 0, 0),
      return_datetime:    Time.new(2025, 3, 16, 12, 0, 0),
      luggage_included:   true,
      price_cents:        price_cents
    )
  end

  subject(:score) { described_class.new(flight_sample, analysis_snapshot).score }

  describe "#score" do
    context "price banding" do
      context "when price is at p25 (cheap)" do
        let(:price_cents) { 10_000 }

        it "returns 100" do
          expect(score).to eq(100)
        end
      end

      context "when price is below p25 (cheap)" do
        let(:price_cents) { 5_000 }

        it "returns 100" do
          expect(score).to eq(100)
        end
      end

      context "when price is between p25 and p50 (below median)" do
        let(:price_cents) { 15_000 }

        it "returns 80" do
          expect(score).to eq(80)
        end
      end

      context "when price equals p50 exactly (below median)" do
        let(:price_cents) { 20_000 }

        it "returns 80" do
          expect(score).to eq(80)
        end
      end

      context "when price is between p50 and p75 (above median)" do
        let(:price_cents) { 25_000 }

        it "returns 50" do
          expect(score).to eq(50)
        end
      end

      context "when price equals p75 exactly (above median)" do
        let(:price_cents) { 30_000 }

        it "returns 50" do
          expect(score).to eq(50)
        end
      end

      context "when price is above p75 (expensive)" do
        let(:price_cents) { 35_000 }

        it "returns 20" do
          expect(score).to eq(20)
        end
      end
    end

    context "missing inputs" do
      it "returns nil when price_cents is nil" do
        sample = Search::Models::FlightSample.new(
          departure_datetime: Time.new(2025, 3, 1, 10, 0, 0),
          return_datetime:    Time.new(2025, 3, 16, 12, 0, 0),
          luggage_included:   true,
          price_cents:        nil
        )

        expect(described_class.new(sample, analysis_snapshot).score).to be_nil
      end

      it "returns nil when price_p25_cents is nil" do
        snapshot = Search::Models::AnalysisSnapshot.new(
          price_p25_cents: nil,
          price_p50_cents: 20_000,
          price_p75_cents: 30_000
        )

        expect(described_class.new(flight_sample, snapshot).score).to be_nil
      end

      it "returns nil when price_p50_cents is nil" do
        snapshot = Search::Models::AnalysisSnapshot.new(
          price_p25_cents: 10_000,
          price_p50_cents: nil,
          price_p75_cents: 30_000
        )

        expect(described_class.new(flight_sample, snapshot).score).to be_nil
      end

      it "returns nil when price_p75_cents is nil" do
        snapshot = Search::Models::AnalysisSnapshot.new(
          price_p25_cents: 10_000,
          price_p50_cents: 20_000,
          price_p75_cents: nil
        )

        expect(described_class.new(flight_sample, snapshot).score).to be_nil
      end
    end

    context "determinism" do
      it "returns the same score for the same inputs" do
        score1 = described_class.new(flight_sample, analysis_snapshot).score
        score2 = described_class.new(flight_sample, analysis_snapshot).score

        expect(score1).to eq(score2)
      end
    end
  end

  describe ".call" do
    it "delegates to #score and returns the same result" do
      instance_score = described_class.new(flight_sample, analysis_snapshot).score
      class_score    = described_class.call(
        flight_sample:     flight_sample,
        analysis_snapshot: analysis_snapshot
      )

      expect(class_score).to eq(instance_score)
    end
  end
end
