# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../app/domain/search/models/search_intent"

RSpec.describe Search::Models::SearchIntent do
  describe "#currency" do
    it "defaults to USD" do
      intent = described_class.new(min_stay_days: 5, max_stay_days: 10, luggage_requirement: :none)
      expect(intent.currency).to eq("USD")
    end

    it "stores the provided currency" do
      intent = described_class.new(min_stay_days: 5, max_stay_days: 10, luggage_requirement: :none, currency: "BRL")
      expect(intent.currency).to eq("BRL")
    end
  end
end
