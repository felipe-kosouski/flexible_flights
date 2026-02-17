# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::SearchRunMapper do
  let(:search_run_record) do
    SearchRun.new(
      state: :initialized,
      started_at: nil,
      completed_at: nil
    )
  end

  let(:domain_run) do
    run = Search::SearchRun.allocate

    run.instance_variable_set(:@state, :completed)
    run.instance_variable_set(:@started_at, Time.new(2025, 2, 10, 10, 0, 0))
    run.instance_variable_set(:@finished_at, Time.new(2025, 2, 10, 10, 5, 0))
    run.instance_variable_set(:@results, [ double("FlightSample") ])
    run.instance_variable_set(:@error, nil)

    run
  end

  describe ".apply" do
    before do
      described_class.apply(domain_run, search_run_record)
    end

    it "maps domain state to record status" do
      expect(search_run_record.state).to eq(:completed)
    end

    it "maps started_at timestamp" do
      expect(search_run_record.started_at)
        .to eq(Time.new(2025, 2, 10, 10, 0, 0))
    end

    it "maps finished_at timestamp" do
      expect(search_run_record.finished_at)
        .to eq(Time.new(2025, 2, 10, 10, 5, 0))
    end

    it "does not save the record" do
      expect(search_run_record).not_to be_persisted
    end

    it "does not change immutable fields" do
      expect(search_run_record.search_intent_id).to be_nil
    end
  end

  context "when domain run failed" do
    let(:domain_run) do
      run = Search::SearchRun.allocate

      run.instance_variable_set(:@state, :failed)
      run.instance_variable_set(:@started_at, Time.now - 60)
      run.instance_variable_set(:@finished_at, Time.now)
      run.instance_variable_set(:@error, RuntimeError.new("failure"))

      run
    end

    it "maps failed state to record status" do
      described_class.apply(domain_run, search_run_record)

      expect(search_run_record.state).to eq(:failed)
    end
  end
end
