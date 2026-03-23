require "rails_helper"

RSpec.describe StripeConfig do
  describe ".webhook_secret" do
    it "returns the value of STRIPE_WEBHOOK_SECRET" do
      allow(ENV).to receive(:fetch).with("STRIPE_WEBHOOK_SECRET").and_return("whsec_test")
      expect(described_class.webhook_secret).to eq("whsec_test")
    end

    it "raises KeyError when STRIPE_WEBHOOK_SECRET is not set" do
      allow(ENV).to receive(:fetch).with("STRIPE_WEBHOOK_SECRET").and_call_original
      expect { described_class.webhook_secret }.to raise_error(KeyError)
    end
  end
end
