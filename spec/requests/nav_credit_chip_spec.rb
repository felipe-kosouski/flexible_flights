# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Nav credit chip", type: :request do
  describe "chip visibility" do
    it "does not render the chip when signed out" do
      get root_path # unauthenticated: renders home page directly, no redirect
      expect(response.body).not_to include("Search Credits")
      expect(response.body).not_to include("credits-dropdown")
    end

    it "renders the chip when signed in" do
      user = create(:user, search_credits: 3)
      sign_in user
      get root_path
      follow_redirect!
      expect(response.body).to include("credits-dropdown")
      expect(response.body).to include("3 credits")
    end
  end

  describe "chip label per state" do
    before do
      sign_in user
      get root_path
      follow_redirect!
    end

    context "when healthy (≥ 2 credits)" do
      let(:user) { create(:user, search_credits: 5) }

      it "shows the credit count" do
        expect(response.body).to include("5 credits")
      end
    end

    context "when low (1 credit)" do
      let(:user) { create(:user, search_credits: 1) }

      it "shows '1 credit left'" do
        expect(response.body).to include("1 credit left")
      end
    end

    context "when empty (0 credits)" do
      let(:user) { create(:user, search_credits: 0) }

      it "shows 'No credits'" do
        expect(response.body).to include("No credits")
      end
    end
  end

  describe "dropdown content" do
    it "includes a link to the payments page" do
      user = create(:user, search_credits: 3)
      sign_in user
      get root_path
      follow_redirect!
      expect(response.body).to include(new_payment_path)
    end
  end
end
