# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Repositories::SearchRunRepository do
  describe ".execute" do
    let(:user) { User.create!(email: "test@example.com") }

    let(:search_intent) do
      SearchIntent.create!(
        user: user,
        origin_airport: "NYC",
        destination_airport: "LON",
        earliest_departure: Date.new(2025, 3, 1),
        latest_return: Date.new(2025, 3, 15),
        min_stay_days: 5,
        max_stay_days: 10,
        luggage_requirement: :carry_on,
        max_stops: 2
      )
    end

    let(:search_run_record) do
      SearchRun.create!(
        search_intent: search_intent,
        state: :initialized
      )
    end

    let(:provider) { double("Provider") }

    let(:params) do
      {
        provider: provider,
        max_candidates: 10,
        passengers: 1,
        cabin_class: :economy
      }
    end

    let(:samples) do
      [
        {
          departure_datetime: Time.new(2025, 3, 1),
          return_datetime: Time.new(2025, 3, 6),
          price_cents: 10_000,
          currency: "USD",
          airline_codes: [ "AA" ],
          stops: 1,
          air_time_minutes: 420,
          layover_time_minutes: 90,
          luggage_included: true,
          raw_provider: "test"
        }
      ]
    end

    let(:domain_search_run) do
      instance_double(Search::SearchRun,
        state: :completed,
        started_at: Time.new(2025, 2, 10, 10, 0, 0),
        finished_at: Time.new(2025, 2, 10, 10, 5, 0),
        error: nil,
        results: samples
      )
    end

    let(:domain_intent) do
      Search::Models::SearchIntent.new(
        min_stay_days: 5,
        max_stay_days: 10,
        luggage_requirement: :carry_on,
        max_stops: 2
      )
    end

    let(:flight_sample) do
      Search::Models::FlightSample.new(
        departure_datetime: Time.new(2025, 3, 1),
        return_datetime: Time.new(2025, 3, 6),
        price_cents: 10_000,
        stops: 1,
        air_time_minutes: 420,
        layover_time_minutes: 90,
        luggage_included: true
      )
    end

    let(:analysis_snapshot) do
      Search::Models::AnalysisSnapshot.new(
        price_p25_cents: 8_000,
        price_p50_cents: 10_000,
        price_p75_cents: 15_000,
        route_median_duration_minutes: 500,
        sample_count: 1,
        volatility: :low,
        confidence: :low
      )
    end

    let(:score_result) do
      Search::Scoring::ScoreResult.new(
        value: 82.5,
        components: { price: 100, time_comfort: 80, trip_fit: 75 }
      )
    end

    let(:ranked_flight) do
      Search::Ranking::RankedFlight.new(
        flight: flight_sample,
        score_result: score_result,
        explanation: nil,
        rank: 1
      )
    end

    let(:execution) do
      instance_double(Search::SearchExecution,
        results: samples,
        flight_samples: [ flight_sample ],
        analysis_snapshot: analysis_snapshot,
        scored_results: [ score_result ],
        explanations: [],
        ranked_results: [ ranked_flight ],
        state: :completed,
        error: nil
      )
    end

    before do
      allow(Search::Factories::SearchRunFactory).to receive(:from_record).and_return(domain_search_run)
      allow(Search::Factories::SearchRunFactory).to receive(:intent_from_record).and_return(domain_intent)
      allow(Search::SearchExecution).to receive(:new).and_return(execution)
      allow(execution).to receive(:execute).and_return(execution)
      allow(Search::Mappers::SearchRunMapper).to receive(:apply).and_call_original
    end

    def execute_repository
      described_class.execute(search_run_record, **params)
    end

    context "happy path" do
      it "executes via SearchExecution" do
        execute_repository

        expect(execution).to have_received(:execute).once
      end

      it "persists the search run state transitions" do
        execute_repository

        search_run_record.reload
        expect(search_run_record.state).to eq("completed")
        expect(search_run_record.started_at).not_to be_nil
        expect(search_run_record.finished_at).not_to be_nil
      end

      it "persists produced flight samples" do
        expect { execute_repository }.to change { FlightSample.count }.by(1)

        sample = FlightSample.last
        expect(sample.search_run).to eq(search_run_record)
        expect(sample.price_cents).to eq(10_000)
        expect(sample.provider).to eq("test")
      end

      it "persists the analysis snapshot" do
        expect { execute_repository }.to change { AnalysisSnapshot.count }.by(1)

        snapshot = AnalysisSnapshot.last
        expect(snapshot.search_run).to eq(search_run_record)
        expect(snapshot.price_p25_cents).to eq(8_000)
        expect(snapshot.price_p50_cents).to eq(10_000)
        expect(snapshot.price_p75_cents).to eq(15_000)
        expect(snapshot.confidence_level).to eq("low")
        expect(snapshot.volatility).to eq("low")
      end

      it "returns the execution object" do
        result = execute_repository

        expect(result).to eq(execution)
      end
    end

    context "when analysis snapshot is nil" do
      let(:execution) do
        instance_double(Search::SearchExecution,
          results: samples,
          flight_samples: [ flight_sample ],
          analysis_snapshot: nil,
          scored_results: [],
          explanations: [],
          ranked_results: [],
          state: :completed,
          error: nil
        )
      end

      it "does not persist an analysis snapshot" do
        expect { execute_repository }.not_to change { AnalysisSnapshot.count }
      end

      it "still persists flight samples" do
        expect { execute_repository }.to change { FlightSample.count }.by(1)
      end
    end

    context "transaction behavior" do
      it "wraps execution in a database transaction" do
        expect(ActiveRecord::Base).to receive(:transaction).and_call_original

        execute_repository
      end

      it "rolls back all persistence if execution fails" do
        allow(execution).to receive(:execute).and_raise(RuntimeError, "provider error")

        failing_run = instance_double(Search::SearchRun,
          state: :failed,
          started_at: Time.now,
          finished_at: Time.now,
          error: RuntimeError.new("provider error"),
          results: []
        )
        allow(Search::Factories::SearchRunFactory).to receive(:from_record).and_return(failing_run)

        expect {
          execute_repository rescue nil
        }.not_to change { FlightSample.count }
      end
    end

    context "error handling" do
      before do
        failing_run = instance_double(Search::SearchRun,
          state: :failed,
          started_at: Time.now,
          finished_at: Time.now,
          error: RuntimeError.new("sampling failed"),
          results: []
        )
        allow(Search::Factories::SearchRunFactory).to receive(:from_record).and_return(failing_run)
        allow(execution).to receive(:execute).and_raise(RuntimeError, "sampling failed")
      end

      it "re-raises domain errors" do
        expect { execute_repository }.to raise_error(RuntimeError, "sampling failed")
      end

      it "persists failed state when execution raises" do
        execute_repository rescue nil

        search_run_record.reload
        expect(search_run_record.state).to eq("failed")
      end
    end

    context "repository boundaries" do
      it "does not swallow provider errors" do
        failing_run = instance_double(Search::SearchRun,
          state: :failed,
          started_at: Time.now,
          finished_at: Time.now,
          error: StandardError.new("provider timeout"),
          results: []
        )
        allow(failing_run).to receive(:execute).and_raise(StandardError, "provider timeout")
        allow(Search::Factories::SearchRunFactory).to receive(:from_record).and_return(failing_run)
        allow(execution).to receive(:execute).and_raise(StandardError, "provider timeout")

        expect { execute_repository }.to raise_error(StandardError, "provider timeout")
      end
    end
  end
end
