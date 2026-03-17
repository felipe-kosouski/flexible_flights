# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Sampling::Runner do
  let(:origin) { "NYC" }
  let(:destination) { "LON" }

  let(:earliest_departure_date) { Date.new(2025, 3, 1) }
  let(:latest_departure_date) { Date.new(2025, 3, 10) }

  let(:min_stay_days) { 3 }
  let(:max_stay_days) { 7 }

  let(:max_candidates) { 4 }
  let(:passengers) { 1 }
  let(:cabin_class) { :economy }

  let(:provider) { double("Provider") }

  let(:all_date_pairs) do
    [
      [ Date.new(2025, 3, 1), Date.new(2025, 3, 4) ],
      [ Date.new(2025, 3, 2), Date.new(2025, 3, 5) ],
      [ Date.new(2025, 3, 3), Date.new(2025, 3, 6) ]
    ]
  end

  let(:selected_date_pairs) do
    all_date_pairs.first(2)
  end

  let(:samples) do
    [
      { price_cents: 10_000 },
      { price_cents: 12_000 }
    ]
  end

  before do
    allow(Search::Sampling::DateGrid)
      .to receive(:new)
      .and_return(double(generate: all_date_pairs))

    allow(Search::Sampling::CandidateSelector)
      .to receive(:new)
      .and_return(double(select: selected_date_pairs))

    allow(Search::Sampling::Sampler)
      .to receive(:new)
      .and_return(double(call: samples))
  end

  subject(:run) do
    described_class.call(
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

  it "returns sampled results" do
    expect(run).to eq(samples)
  end

  it "builds a date grid with correct parameters" do
    run

    expect(Search::Sampling::DateGrid).to have_received(:new).with(
      earliest_departure_date: earliest_departure_date,
      latest_departure_date: latest_departure_date,
      min_stay_days: min_stay_days,
      max_stay_days: max_stay_days
    )
  end

  it "selects candidates using CandidateSelector" do
    run

    expect(Search::Sampling::CandidateSelector).to have_received(:new).with(
      date_pairs: all_date_pairs,
      max_candidates: max_candidates
    )
  end

  it "passes selected date pairs to Sampler" do
    run

    expect(Search::Sampling::Sampler).to have_received(:new).with(
      origin: origin,
      destination: destination,
      date_pairs: selected_date_pairs,
      passengers: passengers,
      cabin_class: cabin_class,
      provider: provider
    )
  end

  it "returns an empty array when no date pairs are generated" do
    allow(Search::Sampling::DateGrid)
      .to receive(:new)
      .and_return(double(generate: []))

    expect(run).to eq([])
  end

  it "does not call provider when no candidates are selected" do
    allow(Search::Sampling::CandidateSelector)
      .to receive(:new)
      .and_return(double(select: []))

    expect(Search::Sampling::Sampler).not_to receive(:new)

    run
  end
end
