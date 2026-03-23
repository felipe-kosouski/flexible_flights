require "rails_helper"

RSpec.describe "Payments", type: :request do
  let(:user) { create(:user) }

  describe "authentication" do
    it "redirects GET /payments/new to sign in when not authenticated" do
      get new_payment_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects POST /payments to sign in when not authenticated" do
      post payments_path, params: { pack_key: "pack_5" }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /payments/new" do
    before { sign_in user }

    it "returns 200" do
      get new_payment_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /payments" do
    before { sign_in user }

    let(:fake_session) do
      double("Stripe::Checkout::Session", url: "https://checkout.stripe.com/pay/cs_test_xxx")
    end

    context "with a valid pack_key and en locale" do
      it "creates a Checkout Session with the USD price and redirects to Stripe" do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)

        post payments_path, params: { pack_key: "pack_5" }

        expect(Stripe::Checkout::Session).to have_received(:create).with(
          hash_including(
            line_items: [ { price: CREDIT_PACKS[:pack_5][:usd_price_id], quantity: 1 } ],
            mode: "payment"
          )
        )
        expect(response).to redirect_to("https://checkout.stripe.com/pay/cs_test_xxx")
      end
    end

    context "with pt-BR locale" do
      it "creates a Checkout Session with the BRL price" do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)

        post payments_path,
          params: { pack_key: "pack_5" },
          headers: { "Accept-Language" => "pt-BR" }

        expect(Stripe::Checkout::Session).to have_received(:create).with(
          hash_including(
            line_items: [ { price: CREDIT_PACKS[:pack_5][:brl_price_id], quantity: 1 } ]
          )
        )
      end
    end

    context "with an unknown pack_key" do
      it "returns 422 and does not call Stripe" do
        allow(Stripe::Checkout::Session).to receive(:create)

        post payments_path, params: { pack_key: "pack_999" }

        expect(Stripe::Checkout::Session).not_to have_received(:create)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /payments/success" do
    before { sign_in user }

    it "returns 200" do
      get success_payments_path
      expect(response).to have_http_status(:ok)
    end
  end
end
