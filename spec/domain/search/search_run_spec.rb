# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::SearchRun do
  let(:origin) { "NYC" }
  let(:destination) { "LON" }
  let(:earliest_departure_date) { Date.new(2025, 3, 1) }
  let(:latest_departure_date) { Date.new(2025, 3, 31) }
  let(:min_stay_days) { 3 }
  let(:max_stay_days) { 10 }
  let(:max_candidates) { 20 }
  let(:passengers) { 1 }
  let(:cabin_class) { :economy }
  let(:provider) { double("Provider") }

  let(:runner) { class_double(Search::Sampling::Runner) }
  let(:snapshot_builder) { class_double(Search::Analysis::SnapshotBuilder) }
  let(:scorer_class) { class_double(Search::Scoring::Scorer) }

  let(:search_run) do
    described_class.new(
      origin: origin,
      destination: destination,
      earliest_departure_date: earliest_departure_date,
      latest_departure_date: latest_departure_date,
      min_stay_days: min_stay_days,
      max_stay_days: max_stay_days,
      max_candidates: max_candidates,
      passengers: passengers,
      cabin_class: cabin_class,
      provider: provider
    )
  end

  before do
    stub_const("Search::Sampling::Runner", runner)
    stub_const("Search::Analysis::SnapshotBuilder", snapshot_builder)
    stub_const("Search::Scoring::Scorer", scorer_class)
    allow(snapshot_builder).to receive(:build).and_return(instance_double(Search::Models::AnalysisSnapshot))
    allow(scorer_class).to receive(:new).and_return(instance_double(Search::Scoring::Scorer, call: 0.75))
  end

  describe "PHASES" do
    it "declares the full ordered lifecycle" do
      expect(described_class::PHASES).to eq(%i[
        initialized
        sampling
        analyzing
        scoring
        completed
        failed
      ])
    end
  end

  describe "initial state" do
    it "starts in initialized state" do
      expect(search_run.state).to eq(:initialized)
    end

    it "has no timestamps set" do
      expect(search_run.started_at).to be_nil
      expect(search_run.finished_at).to be_nil
    end

    it "has no error" do
      expect(search_run.error).to be_nil
    end

    it "has empty results" do
      expect(search_run.results).to eq([])
    end

    it "has no analysis snapshot" do
      expect(search_run.analysis_snapshot).to be_nil
    end

    it "has empty scored results" do
      expect(search_run.scored_results).to eq([])
    end
  end

  describe "#execute — happy path" do
    let(:samples) do
      [
        { price_cents: 10_000, departure_date: earliest_departure_date },
        { price_cents: 12_000, departure_date: earliest_departure_date + 1 }
      ]
    end

    before do
      allow(runner).to receive(:call).and_return(samples)
    end

    it "transitions state through sampling and analysis to completed" do
      search_run.execute

      expect(search_run.state).to eq(:completed)
    end

    it "sets started_at before sampling begins" do
      search_run.execute

      expect(search_run.started_at).not_to be_nil
    end

    it "sets finished_at after sampling completes" do
      search_run.execute

      expect(search_run.finished_at).not_to be_nil
      expect(search_run.finished_at).to be > search_run.started_at
    end

    it "invokes Sampling::Runner exactly once with correct arguments" do
      search_run.execute

      expect(runner).to have_received(:call).once.with(
        origin: origin,
        destination: destination,
        earliest_departure_date: earliest_departure_date,
        latest_departure_date: latest_departure_date,
        min_stay_days: min_stay_days,
        max_stay_days: max_stay_days,
        max_candidates: max_candidates,
        passengers: passengers,
        cabin_class: cabin_class,
        provider: provider
      )
    end

    it "stores returned samples as results" do
      search_run.execute

      expect(search_run.results).to eq(samples)
    end

    it "does not set error" do
      search_run.execute

      expect(search_run.error).to be_nil
    end
  end

  describe "#execute — empty result set" do
    before do
      allow(runner).to receive(:call).and_return([])
    end

    it "completes successfully with empty results" do
      search_run.execute

      expect(search_run.state).to eq(:completed)
      expect(search_run.results).to eq([])
      expect(search_run.error).to be_nil
    end
  end

  describe "#execute — failure path" do
    let(:exception) { StandardError.new("sampling failed") }

    before do
      allow(runner).to receive(:call).and_raise(exception)
    end

    it "transitions to failed state" do
      expect { search_run.execute rescue nil }.to change {
        search_run.state
      }.to(:failed)
    end

    it "sets error to the raised exception" do
      begin
        search_run.execute
      rescue StandardError
      end

      expect(search_run.error).to eq(exception)
    end

    it "sets finished_at even on failure" do
      begin
        search_run.execute
      rescue StandardError
      end

      expect(search_run.finished_at).not_to be_nil
    end

    it "re-raises the exception" do
      expect { search_run.execute }.to raise_error(StandardError, "sampling failed")
    end
  end

  describe "#execute — nil analysis (insufficient data)" do
    let(:samples) do
      [
        { price_cents: 10_000, departure_date: earliest_departure_date }
      ]
    end

    before do
      allow(runner).to receive(:call).and_return(samples)
      allow(snapshot_builder).to receive(:build).and_return(nil)
    end

    it "completes successfully when analysis cannot be built" do
      expect { search_run.execute }.not_to raise_error
    end

    it "sets state to completed" do
      search_run.execute

      expect(search_run.state).to eq(:completed)
    end

    it "preserves results" do
      search_run.execute

      expect(search_run.results).to eq(samples)
    end

    it "leaves analysis_snapshot as nil" do
      search_run.execute

      expect(search_run.analysis_snapshot).to be_nil
    end
  end

  describe "#execute — scoring phase" do
    let(:samples) do
      [
        { price_cents: 10_000, departure_date: earliest_departure_date },
        { price_cents: 12_000, departure_date: earliest_departure_date + 1 }
      ]
    end
    let(:snapshot) { instance_double(Search::Models::AnalysisSnapshot) }
    let(:scorer_instance) { instance_double(Search::Scoring::Scorer, call: 0.82) }

    before do
      allow(runner).to receive(:call).and_return(samples)
      allow(snapshot_builder).to receive(:build).and_return(snapshot)
      allow(scorer_class).to receive(:new).and_return(scorer_instance)
    end

    it "enters the :scoring state during execution" do
      states = []
      allow(scorer_class).to receive(:new) do
        states << search_run.state
        scorer_instance
      end

      search_run.execute

      expect(states).to all(eq(:scoring))
    end

    it "invokes Scorer once per flight sample" do
      search_run.execute

      expect(scorer_class).to have_received(:new).exactly(samples.size).times
    end

    it "passes the correct arguments to each Scorer instance" do
      search_run.execute

      samples.each do |sample|
        expect(scorer_class).to have_received(:new).with(
          flight: sample,
          intent: an_instance_of(Search::Models::SearchIntent),
          snapshot: snapshot
        )
      end
    end

    it "populates scored_results with the return value of each scorer" do
      search_run.execute

      expect(search_run.scored_results).to eq([ 0.82, 0.82 ])
    end

    it "completes successfully" do
      search_run.execute

      expect(search_run.state).to eq(:completed)
    end
  end

  describe "#execute — scoring skipped (nil analysis)" do
    before do
      allow(runner).to receive(:call).and_return([ { price_cents: 10_000 } ])
      allow(snapshot_builder).to receive(:build).and_return(nil)
    end

    it "leaves scored_results empty" do
      search_run.execute

      expect(search_run.scored_results).to eq([])
    end

    it "never instantiates Scorer" do
      search_run.execute

      expect(scorer_class).not_to have_received(:new)
    end

    it "completes successfully" do
      search_run.execute

      expect(search_run.state).to eq(:completed)
    end
  end

  describe "#execute — idempotency" do
    before do
      allow(runner).to receive(:call).and_return([])
      search_run.execute
    end

    it "raises when called again after completion" do
      expect { search_run.execute }.to raise_error(StandardError)
    end

    it "does not invoke Sampling::Runner again" do
      expect { search_run.execute rescue nil }.not_to change {
        runner
      }
    end
  end
end
