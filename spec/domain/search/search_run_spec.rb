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
  end

  describe "PHASES" do
    it "declares the full ordered lifecycle" do
      expect(described_class::PHASES).to eq(%i[
        initialized
        sampling
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
  end

  describe "#execute — happy path" do
    let(:samples) do
      [
        { price_cents: 10_000, departure_datetime: earliest_departure_date.to_time },
        { price_cents: 12_000, departure_datetime: (earliest_departure_date + 1).to_time }
      ]
    end

    before do
      allow(runner).to receive(:call).and_return(samples)
    end

    it "transitions state to completed" do
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

    it "returns self" do
      expect(search_run.execute).to eq(search_run)
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
