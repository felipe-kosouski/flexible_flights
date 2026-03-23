require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:search_intents) }
  end

  describe "search_credits" do
    it "defaults to 1 on creation" do
      user = create(:user)
      expect(user.search_credits).to eq(1)
    end

    it "has a has_many relationship with credit_purchases" do
      is_expected.to have_many(:credit_purchases)
    end
  end

  describe "database constraints" do
    it "enforces email uniqueness" do
      create(:user, email: "dup@example.com")

      expect { create(:user, email: "dup@example.com") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "accepts two users with different emails" do
      expect {
        create(:user, email: "a@example.com")
        create(:user, email: "b@example.com")
      }.to change(User, :count).by(2)
    end
  end

  describe "preferred_locale" do
    it "is valid when nil (browser detection used)" do
      user = build(:user, preferred_locale: nil)
      expect(user).to be_valid
    end

    it "is valid for a supported locale" do
      user = build(:user, preferred_locale: "pt-BR")
      expect(user).to be_valid
    end

    it "is invalid for an unsupported locale" do
      user = build(:user, preferred_locale: "fr")
      expect(user).not_to be_valid
      expect(user.errors[:preferred_locale]).to be_present
    end
  end
end
