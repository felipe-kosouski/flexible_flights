# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::SearchRunRepository do
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
        max_stay_days: 10
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
          departure_date: Date.new(2025, 3, 1),
          return_date: Date.new(2025, 3, 6),
          price_cents: 10_000,
          currency: "USD",
          airline_codes: [ "AA" ],
          stops_count: 1,
          air_time_minutes: 420,
          layover_time_minutes: 90,
          baggage_included: true,
          raw_provider: "test"
        }
      ]
    end

    let(:search_run) do
      instance_double(Search::SearchRun,
        state: :completed,
        started_at: Time.new(2025, 2, 10, 10, 0, 0),
        finished_at: Time.new(2025, 2, 10, 10, 5, 0),
        error: nil,
        results: samples,
        execute: samples
      )
    end

    before do
      allow(Search::SearchRunFactory).to receive(:from_record).and_return(search_run)
      allow(Search::SearchRunMapper).to receive(:apply).and_call_original
    end

    def execute_repository
      described_class.execute(search_run_record, **params)
    end

    context "happy path" do
      it "executes the domain search run" do
        execute_repository

        expect(search_run).to have_received(:execute).once
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

      it "returns the domain results" do
        result = execute_repository

        expect(result).to eq(samples)
      end
    end

    context "transaction behavior" do
      it "wraps execution in a database transaction" do
        expect(ActiveRecord::Base).to receive(:transaction).and_call_original

        execute_repository
      end

      it "rolls back all persistence if domain execution fails" do
        failing_search_run = instance_double(Search::SearchRun,
          state: :failed,
          started_at: Time.now,
          finished_at: Time.now,
          error: RuntimeError.new("provider error"),
          results: []
        )
        allow(failing_search_run).to receive(:execute).and_raise(RuntimeError, "provider error")
        allow(Search::SearchRunFactory).to receive(:from_record).and_return(failing_search_run)

        expect {
          execute_repository rescue nil
        }.not_to change { FlightSample.count }
      end
    end

    context "error handling" do
      let(:search_run) do
        failing_search_run = instance_double(Search::SearchRun,
          state: :failed,
          started_at: Time.now,
          finished_at: Time.now,
          error: RuntimeError.new("sampling failed"),
          results: []
        )
        allow(failing_search_run).to receive(:execute).and_raise(RuntimeError, "sampling failed")
        failing_search_run
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
      it "does not expose ActiveRecord objects in return value" do
        result = execute_repository

        expect(result).to be_an(Array)
        result.each do |item|
          expect(item).not_to be_a(ActiveRecord::Base)
        end
      end

      it "does not swallow provider errors" do
        failing_run = instance_double(Search::SearchRun,
          state: :failed,
          started_at: Time.now,
          finished_at: Time.now,
          error: StandardError.new("provider timeout"),
          results: []
        )
        allow(failing_run).to receive(:execute).and_raise(StandardError, "provider timeout")
        allow(Search::SearchRunFactory).to receive(:from_record).and_return(failing_run)

        expect { execute_repository }.to raise_error(StandardError, "provider timeout")
      end
    end
  end
end
