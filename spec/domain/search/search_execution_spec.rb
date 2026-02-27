# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::SearchExecution do
  let(:raw_samples) do
    [
      {
        price_cents: 10_000,
        stops: 0,
        air_time_minutes: 300,
        layover_time_minutes: 0,
        departure_datetime: Time.new(2025, 3, 1, 10, 0),
        return_datetime: Time.new(2025, 3, 8, 14, 0),
        luggage_included: true,
        currency: "USD",
        airline_codes: [ "AA" ],
        raw_provider: "test"
      },
      {
        price_cents: 15_000,
        stops: 1,
        air_time_minutes: 350,
        layover_time_minutes: 60,
        departure_datetime: Time.new(2025, 3, 2, 12, 0),
        return_datetime: Time.new(2025, 3, 9, 16, 0),
        luggage_included: false,
        currency: "USD",
        airline_codes: [ "UA" ],
        raw_provider: "test"
      }
    ]
  end

  let(:search_run) do
    instance_double(
      Search::SearchRun,
      execute: nil,
      results: raw_samples,
      state: :completed
    )
  end

  let(:intent) do
    Search::Models::SearchIntent.new(
      min_stay_days: 5,
      max_stay_days: 10,
      luggage_requirement: :optional
    )
  end

  let(:snapshot) do
    instance_double(Search::Models::AnalysisSnapshot)
  end

  let(:mapper_class) { class_double(Search::Mappers::FlightSampleMapper) }
  let(:snapshot_builder) { class_double(Search::Analysis::SnapshotBuilder) }
  let(:scorer_class) { class_double(Search::Scoring::Scorer) }
  let(:builder_class) { class_double(Search::Explanation::Builder) }

  let(:flight_sample_a) { instance_double(Search::Models::FlightSample) }
  let(:flight_sample_b) { instance_double(Search::Models::FlightSample) }
  let(:mapped_samples) { [ flight_sample_a, flight_sample_b ] }

  let(:score_result) do
    Search::Scoring::ScoreResult.new(
      value: 82.5,
      components: { price: 100, time_comfort: 80, trip_fit: 75 }
    )
  end

  let(:explanation) { instance_double(Search::Explanation::FlightExplanation) }

  subject(:execution) { described_class.new(search_run: search_run, intent: intent) }

  before do
    stub_const("Search::Mappers::FlightSampleMapper", mapper_class)
    stub_const("Search::Analysis::SnapshotBuilder", snapshot_builder)
    stub_const("Search::Scoring::Scorer", scorer_class)
    stub_const("Search::Explanation::Builder", builder_class)

    allow(mapper_class).to receive(:map_all).and_return(mapped_samples)
    allow(snapshot_builder).to receive(:build).and_return(snapshot)
    allow(scorer_class).to receive(:new).and_return(
      instance_double(Search::Scoring::Scorer, call: score_result)
    )
    allow(builder_class).to receive(:call).and_return(explanation)
  end

  describe "initial state" do
    it "starts in initialized state" do
      expect(execution.state).to eq(:initialized)
    end

    it "has empty flight_samples" do
      expect(execution.flight_samples).to eq([])
    end

    it "has no analysis_snapshot" do
      expect(execution.analysis_snapshot).to be_nil
    end

    it "has empty scored_results" do
      expect(execution.scored_results).to eq([])
    end

    it "has empty explanations" do
      expect(execution.explanations).to eq([])
    end

    it "has no error" do
      expect(execution.error).to be_nil
    end
  end

  describe "#execute — happy path" do
    it "transitions to completed state" do
      execution.execute

      expect(execution.state).to eq(:completed)
    end

    it "executes the search run" do
      execution.execute

      expect(search_run).to have_received(:execute).once
    end

    it "maps raw samples to domain models" do
      execution.execute

      expect(mapper_class).to have_received(:map_all).with(raw_samples)
    end

    it "stores mapped flight samples" do
      execution.execute

      expect(execution.flight_samples).to eq(mapped_samples)
    end

    it "builds an analysis snapshot from mapped samples" do
      execution.execute

      expect(snapshot_builder).to have_received(:build).with(mapped_samples)
    end

    it "stores the analysis snapshot" do
      execution.execute

      expect(execution.analysis_snapshot).to eq(snapshot)
    end

    it "scores each mapped flight sample" do
      execution.execute

      expect(scorer_class).to have_received(:new).exactly(mapped_samples.size).times
    end

    it "passes correct arguments to each scorer" do
      execution.execute

      mapped_samples.each do |sample|
        expect(scorer_class).to have_received(:new).with(
          flight: sample,
          intent: intent,
          snapshot: snapshot
        )
      end
    end

    it "stores ScoreResult objects as scored results" do
      execution.execute

      expect(execution.scored_results).to all(be_a(Search::Scoring::ScoreResult))
      expect(execution.scored_results.size).to eq(2)
    end

    it "builds explanations for each scored flight" do
      execution.execute

      mapped_samples.each do |sample|
        expect(builder_class).to have_received(:call).with(
          flight: sample,
          intent: intent,
          snapshot: snapshot,
          score_result: score_result
        )
      end
    end

    it "stores explanations" do
      execution.execute

      expect(execution.explanations).to eq([ explanation, explanation ])
    end

    it "exposes raw results through the search run" do
      execution.execute

      expect(execution.results).to eq(raw_samples)
    end

    it "returns self" do
      expect(execution.execute).to eq(execution)
    end
  end

  describe "#execute — nil analysis (insufficient data)" do
    before do
      allow(snapshot_builder).to receive(:build).and_return(nil)
    end

    it "completes successfully" do
      execution.execute

      expect(execution.state).to eq(:completed)
    end

    it "leaves analysis_snapshot as nil" do
      execution.execute

      expect(execution.analysis_snapshot).to be_nil
    end

    it "leaves scored_results empty" do
      execution.execute

      expect(execution.scored_results).to eq([])
    end

    it "leaves explanations empty" do
      execution.execute

      expect(execution.explanations).to eq([])
    end

    it "never instantiates a Scorer" do
      execution.execute

      expect(scorer_class).not_to have_received(:new)
    end

    it "never calls the Explanation Builder" do
      execution.execute

      expect(builder_class).not_to have_received(:call)
    end

    it "still stores mapped flight samples" do
      execution.execute

      expect(execution.flight_samples).to eq(mapped_samples)
    end
  end

  describe "#execute — when Builder returns nil for some flights" do
    before do
      allow(builder_class).to receive(:call).and_return(explanation, nil)
    end

    it "filters out nil explanations" do
      execution.execute

      expect(execution.explanations).to eq([ explanation ])
    end
  end

  describe "#execute — empty samples" do
    let(:search_run) do
      instance_double(
        Search::SearchRun,
        execute: nil,
        results: [],
        state: :completed
      )
    end

    before do
      allow(mapper_class).to receive(:map_all).and_return([])
      allow(snapshot_builder).to receive(:build).and_return(nil)
    end

    it "completes successfully" do
      execution.execute

      expect(execution.state).to eq(:completed)
    end

    it "has empty flight_samples" do
      execution.execute

      expect(execution.flight_samples).to eq([])
    end

    it "has empty scored_results" do
      execution.execute

      expect(execution.scored_results).to eq([])
    end

    it "has empty explanations" do
      execution.execute

      expect(execution.explanations).to eq([])
    end
  end

  describe "#execute — failure path" do
    context "when search_run fails" do
      before do
        allow(search_run).to receive(:execute).and_raise(StandardError, "provider error")
      end

      it "transitions to failed state" do
        execution.execute rescue nil

        expect(execution.state).to eq(:failed)
      end

      it "sets the error" do
        execution.execute rescue nil

        expect(execution.error).to be_a(StandardError)
        expect(execution.error.message).to eq("provider error")
      end

      it "re-raises the exception" do
        expect { execution.execute }.to raise_error(StandardError, "provider error")
      end

      it "does not attempt mapping or analysis" do
        execution.execute rescue nil

        expect(mapper_class).not_to have_received(:map_all)
        expect(snapshot_builder).not_to have_received(:build)
      end
    end

    context "when analysis raises" do
      before do
        allow(snapshot_builder).to receive(:build).and_raise(StandardError, "analysis error")
      end

      it "transitions to failed state" do
        execution.execute rescue nil

        expect(execution.state).to eq(:failed)
      end

      it "re-raises the exception" do
        expect { execution.execute }.to raise_error(StandardError, "analysis error")
      end
    end
  end

  describe "pipeline ordering" do
    it "executes phases in order: sampling, mapping, analyzing, scoring, explaining" do
      phase_log = []

      allow(search_run).to receive(:execute) { phase_log << :sampling }
      allow(mapper_class).to receive(:map_all) { phase_log << :mapping; mapped_samples }
      allow(snapshot_builder).to receive(:build) { phase_log << :analyzing; snapshot }
      allow(scorer_class).to receive(:new) do
        phase_log << :scoring
        instance_double(Search::Scoring::Scorer, call: score_result)
      end
      allow(builder_class).to receive(:call) do
        phase_log << :explaining
        explanation
      end

      execution.execute

      expect(phase_log).to eq([ :sampling, :mapping, :analyzing, :scoring, :scoring, :explaining, :explaining ])
    end
  end
end
