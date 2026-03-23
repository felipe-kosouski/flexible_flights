FactoryBot.define do
  factory :credit_purchase do
    association :user
    sequence(:stripe_session_id) { |n| "cs_test_#{n}" }
    pack_key { "pack_5" }
    credits_granted { 5 }
    currency { "usd" }
    amount_cents { 299 }
    fulfilled_at { Time.current }
  end
end
