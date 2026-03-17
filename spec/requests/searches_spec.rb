# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Searches", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "authentication guards" do
    context "when not signed in" do
      it "redirects GET /searches/new to sign in" do
        get new_search_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects POST /searches to sign in" do
        post searches_path, params: { search_intent: { origin_airport: "JFK" } }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects GET /searches/:id to sign in" do
        search_intent = create(:search_intent, user: user)
        search_run = create(:search_run, search_intent: search_intent)
        get search_path(search_run)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "allows GET /searches/new" do
        get new_search_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "IDOR protection on searches#show" do
    before { sign_in user }

    it "redirects to new search when accessing another user's search run" do
      search_intent = create(:search_intent, user: other_user)
      search_run = create(:search_run, search_intent: search_intent)

      get search_path(search_run)
      expect(response).to redirect_to(new_search_path)
    end
  end
end
