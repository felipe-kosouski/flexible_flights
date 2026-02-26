# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Models::AnalysisSnapshot do
  subject(:snapshot) do
    described_class.new(
      price_p25_cents: 5_000,
      price_p50_cents: 8_000,
      price_p75_cents: 12_000,
      route_median_duration_minutes: 180,
      sample_count: 25,
      volatility: :medium,
      confidence: :high
    )
  end

  describe "attribute readers" do
    it { expect(snapshot.price_p25_cents).to eq(5_000) }
    it { expect(snapshot.price_p50_cents).to eq(8_000) }
    it { expect(snapshot.price_p75_cents).to eq(12_000) }
    it { expect(snapshot.route_median_duration_minutes).to eq(180) }
    it { expect(snapshot.sample_count).to eq(25) }
    it { expect(snapshot.volatility).to eq(:medium) }
    it { expect(snapshot.confidence).to eq(:high) }
  end

  describe "#price_distribution_present?" do
    context "when all three price percentiles are present" do
      it { expect(snapshot.price_distribution_present?).to be_truthy }
    end

    context "when price_p25_cents is missing" do
      subject(:snapshot) { described_class.new(price_p50_cents: 8_000, price_p75_cents: 12_000) }

      it { expect(snapshot.price_distribution_present?).to be_falsy }
    end

    context "when price_p50_cents is missing" do
      subject(:snapshot) { described_class.new(price_p25_cents: 5_000, price_p75_cents: 12_000) }

      it { expect(snapshot.price_distribution_present?).to be_falsy }
    end

    context "when price_p75_cents is missing" do
      subject(:snapshot) { described_class.new(price_p25_cents: 5_000, price_p50_cents: 8_000) }

      it { expect(snapshot.price_distribution_present?).to be_falsy }
    end

    context "when all price percentiles are missing" do
      subject(:snapshot) { described_class.new }

      it { expect(snapshot.price_distribution_present?).to be_falsy }
    end
  end

  describe "immutability" do
    it "does not expose setter methods" do
      expect(snapshot).not_to respond_to(:price_p25_cents=)
      expect(snapshot).not_to respond_to(:volatility=)
      expect(snapshot).not_to respond_to(:confidence=)
    end
  end

  describe "optional attributes default to nil" do
    subject(:snapshot) { described_class.new }

    it { expect(snapshot.price_p25_cents).to be_nil }
    it { expect(snapshot.price_p50_cents).to be_nil }
    it { expect(snapshot.price_p75_cents).to be_nil }
    it { expect(snapshot.route_median_duration_minutes).to be_nil }
    it { expect(snapshot.sample_count).to be_nil }
    it { expect(snapshot.volatility).to be_nil }
    it { expect(snapshot.confidence).to be_nil }
  end
end
