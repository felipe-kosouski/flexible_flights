# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Scoring::TripFit do
  subject(:score) { described_class.new(flight_sample, search_intent).score }

  let(:search_intent) do
    Search::Models::SearchIntent.new(
      min_stay_days: 10,
      max_stay_days: 20,
      luggage_requirement: luggage_requirement
    )
  end

  let(:flight_sample) do
    Search::Models::FlightSample.new(
      departure_datetime: departure_datetime,
      return_datetime: return_datetime,
      luggage_included: luggage_included
    )
  end

  let(:departure_datetime) { Time.new(2025, 3, 1, 10, 0, 0) }
  let(:return_datetime)   { Time.new(2025, 3, 16, 12, 0, 0) } # 15 days
  let(:luggage_included)  { true }
  let(:luggage_requirement) { :required }

  describe "#score" do
    context "trip length fit" do
      it "returns 100 when stay length is exactly at midpoint" do
        expect(score).to be_within(1).of(100)
      end

      it "returns a high score when within ±20% of the range" do
        intent = Search::Models::SearchIntent.new(
          min_stay_days: 8,
          max_stay_days: 20,
          luggage_requirement: luggage_requirement
        )

        score = described_class.new(flight_sample, intent).score
        expect(score).to be > 80
      end

      it "returns a lower score near the edges of the range" do
        sample = Search::Models::FlightSample.new(
          departure_datetime: departure_datetime,
          return_datetime: Time.new(2025, 3, 11, 12, 0, 0), # 10 days
          luggage_included: luggage_included
        )

        score = described_class.new(sample, search_intent).score
        expect(score).to be < 90
      end

      it "returns nil when stay length is far outside the allowed range" do
        sample = Search::Models::FlightSample.new(
          departure_datetime: departure_datetime,
          return_datetime: Time.new(2025, 3, 5, 12, 0, 0), # 4 days
          luggage_included: luggage_included
        )

        score = described_class.new(sample, search_intent).score
        expect(score).to be_nil
      end
    end

    context "luggage fit" do
      context "when luggage is required" do
        let(:luggage_requirement) { :required }

        it "returns nil if luggage is not included" do
          sample = Search::Models::FlightSample.new(
            departure_datetime: departure_datetime,
            return_datetime: return_datetime,
            luggage_included: false
          )

          score = described_class.new(sample, search_intent).score
          expect(score).to be_nil
        end
      end

      context "when luggage is optional" do
        let(:luggage_requirement) { :optional }

        it "applies a small penalty when luggage is not included" do
          sample = Search::Models::FlightSample.new(
            departure_datetime: departure_datetime,
            return_datetime: return_datetime,
            luggage_included: false
          )

          score = described_class.new(sample, search_intent).score
          expect(score).to be_between(50, 95)
        end
      end
    end

    context "departure and arrival time fit" do
      it "penalizes red-eye departures" do
        sample = Search::Models::FlightSample.new(
          departure_datetime: Time.new(2025, 3, 1, 2, 0, 0),
          return_datetime: return_datetime,
          luggage_included: luggage_included
        )

        score = described_class.new(sample, search_intent).score
        expect(score).to be < 95
      end

      it "penalizes very late arrivals" do
        sample = Search::Models::FlightSample.new(
          departure_datetime: departure_datetime,
          return_datetime: Time.new(2025, 3, 16, 1, 30, 0),
          luggage_included: luggage_included
        )

        score = described_class.new(sample, search_intent).score
        expect(score).to be < 95
      end
    end

    context "hard stop behavior" do
      it "returns nil for invalid trip length regardless of other factors" do
        sample = Search::Models::FlightSample.new(
          departure_datetime: departure_datetime,
          return_datetime: Time.new(2025, 3, 3, 12, 0, 0), # 2 days
          luggage_included: true
        )

        score = described_class.new(sample, search_intent).score
        expect(score).to be_nil
      end

      it "returns nil if required luggage is missing even with perfect length" do
        sample = Search::Models::FlightSample.new(
          departure_datetime: departure_datetime,
          return_datetime: return_datetime,
          luggage_included: false
        )

        score = described_class.new(sample, search_intent).score
        expect(score).to be_nil
      end
    end

    context "determinism" do
      it "returns the same score for the same inputs" do
        expect(score).to eq(score)
      end
    end
  end
end
