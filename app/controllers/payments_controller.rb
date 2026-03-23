class PaymentsController < ApplicationController
  before_action :authenticate_user!

  def new
  end

  def create
    pack_key = params[:pack_key].to_sym
    pack = CREDIT_PACKS[pack_key]
    return head :unprocessable_entity unless pack

    currency = CurrencyResolver.for_locale(I18n.locale)
    price_id = currency == "BRL" ? pack[:brl_price_id] : pack[:usd_price_id]

    session = Stripe::Checkout::Session.create(
      customer_email: current_user.email,
      line_items: [ { price: price_id, quantity: 1 } ],
      mode: "payment",
      success_url: success_payments_url(session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: new_payment_url,
      metadata: { user_id: current_user.id, pack_key: pack_key }
    )

    redirect_to session.url, allow_other_host: true
  end

  def success
  end
end
