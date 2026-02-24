# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Scoring::TimeComfortScore do
  let(:analysis_snapshot) do
    Search::Models::AnalysisSnapshot.new(route_median_duration_minutes: 120)
  end

  let(:stops)               { 0 }
  let(:air_time_minutes)    { 100 }
  let(:layover_time_minutes) { 0 }

  let(:flight_sample) do
    Search::Models::FlightSample.new(
      departure_datetime:   Time.new(2025, 3, 1, 10, 0, 0),
      return_datetime:      Time.new(2025, 3, 16, 12, 0, 0),
      luggage_included:     true,
      stops:                stops,
      air_time_minutes:     air_time_minutes,
      layover_time_minutes: layover_time_minutes
    )
  end

  subject(:score) { described_class.new(flight_sample, analysis_snapshot).score }

  describe "#score" do
    context "stops scoring" do
      context "when stops is 0 (non-stop)" do
        let(:stops) { 0 }

        it "contributes a stops score of 100" do
          expect(score).to be_within(0.01).of((100 * 0.6) + (100 * 0.4))
        end
      end

      context "when stops is 1" do
        let(:stops) { 1 }

        it "contributes a stops score of 80" do
          expect(score).to be_within(0.01).of((80 * 0.6) + (100 * 0.4))
        end
      end

      context "when stops is 2" do
        let(:stops) { 2 }

        it "contributes a stops score of 50" do
          expect(score).to be_within(0.01).of((50 * 0.6) + (100 * 0.4))
        end
      end

      context "when stops is 3" do
        let(:stops) { 3 }

        it "contributes the default stops score of 20" do
          expect(score).to be_within(0.01).of((20 * 0.6) + (100 * 0.4))
        end
      end

      context "when stops is 5 (more than 3)" do
        let(:stops) { 5 }

        it "contributes the default stops score of 20" do
          expect(score).to be_within(0.01).of((20 * 0.6) + (100 * 0.4))
        end
      end
    end

    context "duration scoring (with 0 layover, route median 120 min)" do
      # effective_duration == air_time_minutes when layover is 0
      # relative_duration  == air_time / 120

      context "when relative duration is <= 0.9 (air time 100, relative ~0.83)" do
        let(:air_time_minutes) { 100 }

        it "contributes a duration score of 100" do
          expect(score).to be_within(0.01).of((100 * 0.6) + (100 * 0.4))
        end
      end

      context "when relative duration is between 0.9 and 1.1 (air time 120, relative 1.0)" do
        let(:air_time_minutes) { 120 }

        it "contributes a duration score of 80" do
          expect(score).to be_within(0.01).of((100 * 0.6) + (80 * 0.4))
        end
      end

      context "when relative duration is between 1.1 and 1.3 (air time 144, relative 1.2)" do
        let(:air_time_minutes) { 144 }

        it "contributes a duration score of 50" do
          expect(score).to be_within(0.01).of((100 * 0.6) + (50 * 0.4))
        end
      end

      context "when relative duration is > 1.3 (air time 180, relative 1.5)" do
        let(:air_time_minutes) { 180 }

        it "contributes a duration score of 20" do
          expect(score).to be_within(0.01).of((100 * 0.6) + (20 * 0.4))
        end
      end

      context "when layover inflates effective duration (layover_penalty = 1.3)" do
        let(:air_time_minutes)    { 60 }
        let(:layover_time_minutes) { 100 }

        it "penalizes layover time at 1.3x (effective = 60 + 100*1.3 = 190, relative ~1.58 > 1.3)" do
          expect(score).to be_within(0.01).of((100 * 0.6) + (20 * 0.4))
        end
      end
    end

    context "missing inputs" do
      it "returns nil when stops is nil" do
        sample = Search::Models::FlightSample.new(
          departure_datetime:   Time.new(2025, 3, 1, 10, 0, 0),
          return_datetime:      Time.new(2025, 3, 16, 12, 0, 0),
          luggage_included:     true,
          stops:                nil,
          air_time_minutes:     100,
          layover_time_minutes: 0
        )

        expect(described_class.new(sample, analysis_snapshot).score).to be_nil
      end

      it "returns nil when air_time_minutes is nil" do
        sample = Search::Models::FlightSample.new(
          departure_datetime:   Time.new(2025, 3, 1, 10, 0, 0),
          return_datetime:      Time.new(2025, 3, 16, 12, 0, 0),
          luggage_included:     true,
          stops:                0,
          air_time_minutes:     nil,
          layover_time_minutes: 0
        )

        expect(described_class.new(sample, analysis_snapshot).score).to be_nil
      end

      it "returns nil when layover_time_minutes is nil" do
        sample = Search::Models::FlightSample.new(
          departure_datetime:   Time.new(2025, 3, 1, 10, 0, 0),
          return_datetime:      Time.new(2025, 3, 16, 12, 0, 0),
          luggage_included:     true,
          stops:                0,
          air_time_minutes:     100,
          layover_time_minutes: nil
        )

        expect(described_class.new(sample, analysis_snapshot).score).to be_nil
      end

      it "returns nil when route_median_duration_minutes is nil" do
        snapshot = Search::Models::AnalysisSnapshot.new(route_median_duration_minutes: nil)

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
