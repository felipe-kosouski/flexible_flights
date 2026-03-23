require "rails_helper"

RSpec.describe "StripeWebhooks", type: :request do
  let(:user) { create(:user, search_credits: 0) }

  before do
    allow(StripeConfig).to receive(:webhook_secret).and_return("whsec_test")
  end

  def build_event(type:, metadata: {}, session_id: "cs_test_abc", currency: "usd", amount: 299)
    Stripe::Event.construct_from({
      "type" => type,
      "data" => {
        "object" => {
          "id" => session_id,
          "object" => "checkout.session",
          "metadata" => metadata.stringify_keys,
          "currency" => currency,
          "amount_total" => amount
        }
      }
    })
  end

  def post_webhook(event)
    allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
    post "/stripe/webhooks",
      params: "{}",
      headers: {
        "Content-Type" => "application/json",
        "Stripe-Signature" => "t=1,v1=fake"
      }
  end

  describe "signature verification" do
    it "returns 400 when signature is invalid" do
      allow(Stripe::Webhook).to receive(:construct_event)
        .and_raise(Stripe::SignatureVerificationError.new("bad sig", "header"))

      post "/stripe/webhooks",
        params: "{}",
        headers: { "Content-Type" => "application/json", "Stripe-Signature" => "bad" }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "unhandled event types" do
    it "returns 200 without doing anything" do
      event = build_event(type: "payment_intent.created")
      post_webhook(event)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "checkout.session.completed" do
    let(:valid_metadata) { { user_id: user.id, pack_key: "pack_5" } }

    it "grants credits and creates a CreditPurchase record" do
      event = build_event(type: "checkout.session.completed", metadata: valid_metadata)

      expect {
        post_webhook(event)
      }.to change { user.reload.search_credits }.by(5)
        .and change(CreditPurchase, :count).by(1)

      expect(response).to have_http_status(:ok)

      purchase = CreditPurchase.last
      expect(purchase.pack_key).to eq("pack_5")
      expect(purchase.credits_granted).to eq(5)
      expect(purchase.fulfilled_at).to be_present
    end

    it "returns 200 and does not double-grant on duplicate webhook" do
      event = build_event(type: "checkout.session.completed", metadata: valid_metadata, session_id: "cs_dup")
      post_webhook(event) # first delivery

      expect {
        post_webhook(event) # duplicate delivery
      }.not_to change { user.reload.search_credits }

      expect(response).to have_http_status(:ok)
    end

    it "returns 422 when pack_key is unknown" do
      event = build_event(
        type: "checkout.session.completed",
        metadata: { user_id: user.id, pack_key: "pack_999" }
      )
      post_webhook(event)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 200 and logs a warning when user_id is unknown" do
      event = build_event(
        type: "checkout.session.completed",
        metadata: { user_id: 999_999, pack_key: "pack_5" }
      )
      allow(Rails.logger).to receive(:warn)
      post_webhook(event)
      expect(response).to have_http_status(:ok)
      expect(Rails.logger).to have_received(:warn).with(/user not found/i)
    end
  end
end
