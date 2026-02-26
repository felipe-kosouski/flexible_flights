# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Analysis::SnapshotBuilder do
  let(:base_datetime) { Time.zone.parse("2026-06-01 10:00") }

  def build_sample(price_cents: 10_000, air_time_minutes: 120, layover_time_minutes: 30)
    Search::Models::FlightSample.new(
      departure_datetime:   base_datetime,
      return_datetime:      base_datetime + 7.days,
      luggage_included:     true,
      price_cents:          price_cents,
      stops:                0,
      air_time_minutes:     air_time_minutes,
      layover_time_minutes: layover_time_minutes
    )
  end

  describe ".build" do
    context "when the sample list is empty" do
      it "returns nil" do
        expect(described_class.build([])).to be_nil
      end
    end

    context "when all samples have nil price_cents" do
      let(:samples) { 3.times.map { build_sample(price_cents: nil) } }

      it "returns nil" do
        expect(described_class.build(samples)).to be_nil
      end
    end

    context "when all samples have zero price_cents" do
      let(:samples) { 3.times.map { build_sample(price_cents: 0) } }

      it "returns nil" do
        expect(described_class.build(samples)).to be_nil
      end
    end

    context "when all samples are missing duration data" do
      let(:samples) do
        3.times.map { build_sample(air_time_minutes: nil, layover_time_minutes: nil) }
      end

      it "returns nil" do
        expect(described_class.build(samples)).to be_nil
      end
    end

    context "when all samples are missing air_time_minutes only" do
      let(:samples) { 3.times.map { build_sample(air_time_minutes: nil) } }

      it "returns nil" do
        expect(described_class.build(samples)).to be_nil
      end
    end

    context "when all samples are missing layover_time_minutes only" do
      let(:samples) { 3.times.map { build_sample(layover_time_minutes: nil) } }

      it "returns nil" do
        expect(described_class.build(samples)).to be_nil
      end
    end
  end

  describe "price percentile calculation" do
    # Four prices: [2_000, 4_000, 6_000, 8_000] (sorted ascending)
    # Indices 0..3; n-1 = 3
    # p25 = floor(0.25 * 3) = 0 → 2_000
    # p50 = floor(0.50 * 3) = 1 → 4_000
    # p75 = floor(0.75 * 3) = 2 → 6_000
    let(:samples) do
      [ 8_000, 2_000, 6_000, 4_000 ].map { |p| build_sample(price_cents: p) }
    end

    subject(:snapshot) { described_class.build(samples) }

    it "computes p25 via rank-based selection" do
      expect(snapshot.price_p25_cents).to eq(2_000)
    end

    it "computes p50 (median) via rank-based selection" do
      expect(snapshot.price_p50_cents).to eq(4_000)
    end

    it "computes p75 via rank-based selection" do
      expect(snapshot.price_p75_cents).to eq(6_000)
    end

    context "with a single valid price" do
      let(:samples) { [ build_sample(price_cents: 5_000) ] }

      it "returns that single price for all three percentiles" do
        expect(snapshot.price_p25_cents).to eq(5_000)
        expect(snapshot.price_p50_cents).to eq(5_000)
        expect(snapshot.price_p75_cents).to eq(5_000)
      end
    end

    context "when some samples have nil or zero prices" do
      let(:samples) do
        [
          build_sample(price_cents: nil),
          build_sample(price_cents: 0),
          build_sample(price_cents: 3_000),
          build_sample(price_cents: 9_000)
        ]
      end

      it "ignores invalid prices and computes percentiles from valid prices only" do
        # valid: [3_000, 9_000]; p50 = floor(0.5 * 1) = 0 → 3_000
        expect(snapshot.price_p50_cents).to eq(3_000)
      end
    end
  end

  describe "route_median_duration_minutes" do
    # effective = air + (layover * 1.3)
    # Sample A: 100 + (20 * 1.3) = 126
    # Sample B: 200 + (40 * 1.3) = 252
    # Sample C: 300 + (60 * 1.3) = 378
    # Sorted: [126, 252, 378] → p50 = index floor(0.5 * 2) = 1 → 252
    let(:samples) do
      [
        build_sample(air_time_minutes: 100, layover_time_minutes: 20),
        build_sample(air_time_minutes: 200, layover_time_minutes: 40),
        build_sample(air_time_minutes: 300, layover_time_minutes: 60)
      ]
    end

    it "applies the layover penalty (× 1.3) and returns the median" do
      snapshot = described_class.build(samples)
      expect(snapshot.route_median_duration_minutes).to eq(252.0)
    end

    it "ignores samples with missing duration data" do
      samples_with_gaps = samples + [ build_sample(air_time_minutes: nil) ]
      snapshot = described_class.build(samples_with_gaps)
      expect(snapshot.route_median_duration_minutes).to eq(252.0)
    end
  end

  describe "sample_count" do
    it "equals the total number of samples passed in, not just those with valid data" do
      samples = [
        build_sample(price_cents: nil),
        build_sample,
        build_sample
      ]
      snapshot = described_class.build(samples)
      expect(snapshot.sample_count).to eq(3)
    end
  end

  describe "volatility" do
    # Builds 5-sample sets with controlled prices to drive specific spread ratios.
    # For [p25_val, p50_val, p75_val] we need a sorted 5-element array where:
    #   index 1 = p25, index 2 = p50, index 3 = p75
    def samples_for_prices(a, b, c, d, e)
      [ a, b, c, d, e ].map { |p| build_sample(price_cents: p) }
    end

    context "when spread_ratio ≤ 0.20" do
      # prices [900, 950, 1000, 1050, 1100] → p25=950, p50=1000, p75=1050
      # spread = (1050 - 950) / 1000 = 0.10 → :low
      let(:samples) { samples_for_prices(900, 950, 1_000, 1_050, 1_100) }

      it { expect(described_class.build(samples).volatility).to eq(:low) }
    end

    context "when spread_ratio is between 0.20 and 0.40" do
      # prices [700, 800, 1000, 1200, 1400] → p25=800, p50=1000, p75=1200
      # spread = (1200 - 800) / 1000 = 0.40 → :medium (≤ 0.40)
      let(:samples) { samples_for_prices(700, 800, 1_000, 1_200, 1_400) }

      it { expect(described_class.build(samples).volatility).to eq(:medium) }
    end

    context "when spread_ratio > 0.40" do
      # prices [500, 700, 1000, 1500, 2000] → p25=700, p50=1000, p75=1500
      # spread = (1500 - 700) / 1000 = 0.80 → :high
      let(:samples) { samples_for_prices(500, 700, 1_000, 1_500, 2_000) }

      it { expect(described_class.build(samples).volatility).to eq(:high) }
    end
  end

  describe "confidence" do
    # Use prices with a tight spread (→ :low volatility) by default.
    # [900, 950, 1000, 1050, 1100] gives volatility :low.
    let(:low_vol_prices) { [ 900, 950, 1_000, 1_050, 1_100 ] }
    # [500, 700, 1000, 1500, 2000] gives volatility :high.
    let(:high_vol_prices) { [ 500, 700, 1_000, 1_500, 2_000 ] }

    def make_samples(prices, count)
      cycle = prices.cycle
      count.times.map { build_sample(price_cents: cycle.next) }
    end

    context "when sample_count < 10 (regardless of volatility)" do
      let(:samples) { make_samples(low_vol_prices, 5) }

      it { expect(described_class.build(samples).confidence).to eq(:low) }
    end

    context "when volatility is :high (regardless of sample count ≥ 10)" do
      let(:samples) { make_samples(high_vol_prices, 15) }

      it { expect(described_class.build(samples).confidence).to eq(:low) }
    end

    context "when sample_count ≥ 20 and volatility is :low" do
      let(:samples) { make_samples(low_vol_prices, 20) }

      it { expect(described_class.build(samples).confidence).to eq(:high) }
    end

    context "when sample_count is between 10 and 19 with :low volatility" do
      let(:samples) { make_samples(low_vol_prices, 15) }

      it { expect(described_class.build(samples).confidence).to eq(:medium) }
    end

    context "when sample_count ≥ 10 with :medium volatility" do
      # Sorted prices: [500,600,800,900,1000,1000,1100,1200,1200,1300,1400,1500]
      # n=12 → p25=index 2=800, p50=index 5=1000, p75=index 8=1200
      # spread = (1200-800)/1000 = 0.40 → :medium volatility
      let(:samples) do
        [ 500, 600, 800, 900, 1_000, 1_000, 1_100, 1_200, 1_200, 1_300, 1_400, 1_500 ]
          .map { |p| build_sample(price_cents: p) }
      end

      it { expect(described_class.build(samples).confidence).to eq(:medium) }
    end
  end

  describe "determinism" do
    let(:samples) do
      [ 8_000, 2_000, 6_000, 4_000 ].map { |p| build_sample(price_cents: p) }
    end

    it "returns identical snapshots for the same inputs on repeated calls" do
      first  = described_class.build(samples)
      second = described_class.build(samples)

      expect(first.price_p25_cents).to eq(second.price_p25_cents)
      expect(first.price_p50_cents).to eq(second.price_p50_cents)
      expect(first.price_p75_cents).to eq(second.price_p75_cents)
      expect(first.route_median_duration_minutes).to eq(second.route_median_duration_minutes)
      expect(first.volatility).to eq(second.volatility)
      expect(first.confidence).to eq(second.confidence)
    end
  end
end
