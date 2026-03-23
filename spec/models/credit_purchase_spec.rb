require "rails_helper"

RSpec.describe CreditPurchase, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:stripe_session_id) }
    it { is_expected.to validate_presence_of(:pack_key) }
    it { is_expected.to validate_presence_of(:credits_granted) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:amount_cents) }
    it { is_expected.to validate_presence_of(:fulfilled_at) }
  end

  describe "database constraints" do
    it "enforces uniqueness of stripe_session_id at the DB level" do
      user = create(:user)
      create(:credit_purchase, user: user, stripe_session_id: "cs_test_123")
      expect {
        create(:credit_purchase, user: user, stripe_session_id: "cs_test_123")
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
