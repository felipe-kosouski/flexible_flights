# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#credit_chip_state" do
    it "returns :healthy for 5 credits" do
      user = build_stubbed(:user, search_credits: 5)
      expect(helper.credit_chip_state(user)).to eq(:healthy)
    end

    it "returns :healthy for exactly 2 credits" do
      user = build_stubbed(:user, search_credits: 2)
      expect(helper.credit_chip_state(user)).to eq(:healthy)
    end

    it "returns :low for exactly 1 credit" do
      user = build_stubbed(:user, search_credits: 1)
      expect(helper.credit_chip_state(user)).to eq(:low)
    end

    it "returns :empty for 0 credits" do
      user = build_stubbed(:user, search_credits: 0)
      expect(helper.credit_chip_state(user)).to eq(:empty)
    end
  end
end
