Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)

CREDIT_PACKS = {
  pack_5: {
    credits: 5,
    usd_price_id: Rails.application.credentials.dig(:stripe, :price_pack5_usd),
    brl_price_id: Rails.application.credentials.dig(:stripe, :price_pack5_brl)
  },
  pack_15: {
    credits: 15,
    usd_price_id: Rails.application.credentials.dig(:stripe, :price_pack15_usd),
    brl_price_id: Rails.application.credentials.dig(:stripe, :price_pack15_brl)
  },
  pack_30: {
    credits: 30,
    usd_price_id: Rails.application.credentials.dig(:stripe, :price_pack30_usd),
    brl_price_id: Rails.application.credentials.dig(:stripe, :price_pack30_brl)
  }
}.freeze
