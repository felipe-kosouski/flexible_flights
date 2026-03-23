class CreditPurchase < ApplicationRecord
  belongs_to :user

  validates :stripe_session_id, presence: true
  validates :pack_key, presence: true
  validates :credits_granted, presence: true
  validates :currency, presence: true
  validates :amount_cents, presence: true
  validates :fulfilled_at, presence: true
end
