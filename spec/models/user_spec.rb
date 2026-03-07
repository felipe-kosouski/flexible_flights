require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:search_intents) }
  end

  describe "database constraints" do
    it "enforces email uniqueness at the database level" do
      create(:user, email: "dup@example.com")

      expect { create(:user, email: "dup@example.com") }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "accepts two users with different emails" do
      expect {
        create(:user, email: "a@example.com")
        create(:user, email: "b@example.com")
      }.to change(User, :count).by(2)
    end
  end
end
