class StripeWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def create
    event = verify_stripe_event
    return head :bad_request unless event
    return head :ok unless event.type == "checkout.session.completed"

    fulfill_checkout(event.data.object)
  end

  private

  def verify_stripe_event
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    Stripe::Webhook.construct_event(payload, sig_header, StripeConfig.webhook_secret)
  rescue Stripe::SignatureVerificationError
    nil
  end

  def fulfill_checkout(session)
    pack_key = session.metadata[:pack_key]
    pack = CREDIT_PACKS[pack_key&.to_sym]
    return head :unprocessable_entity unless pack

    user = User.find_by(id: session.metadata[:user_id])
    unless user
      Rails.logger.warn("StripeWebhook: user not found for session #{session.id}")
      return head :ok
    end

    ActiveRecord::Base.transaction do
      CreditPurchase.create!(
        user: user,
        stripe_session_id: session.id,
        pack_key: pack_key,
        credits_granted: pack[:credits],
        currency: session.currency.upcase,
        amount_cents: session.amount_total,
        fulfilled_at: Time.current
      )
      User.where(id: user.id).update_all([ "search_credits = search_credits + ?", pack[:credits] ])
    end

    head :ok
  rescue ActiveRecord::RecordNotUnique
    head :ok
  end
end
