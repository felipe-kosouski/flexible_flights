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

  describe "credit gate on POST /searches" do
    before { sign_in user }

    let(:valid_params) do
      {
        search_intent: {
          origin_airport: "GRU",
          destination_airport: "JFK",
          earliest_departure: 30.days.from_now.to_date.to_s,
          latest_return: 60.days.from_now.to_date.to_s,
          min_stay_days: 5,
          max_stay_days: 10,
          luggage_requirement: "none",
          max_stops: 1
        }
      }
    end

    context "when user has 0 credits" do
      before { user.update!(search_credits: 0) }

      it "redirects to new_payment_path without enqueuing a job" do
        expect(SearchRunJob).not_to receive(:perform_later)
        post searches_path, params: valid_params
        expect(response).to redirect_to(new_payment_path)
      end
    end

    context "when user has 1 or more credits" do
      before { user.update!(search_credits: 1) }

      it "enqueues a SearchRunJob" do
        expect(SearchRunJob).to receive(:perform_later)
        post searches_path, params: valid_params
      end
    end
  end

  describe "GET /searches/new with from_intent param" do
    before { sign_in user }

    context "with a valid from_intent belonging to current user" do
      it "returns 200 and pre-fills the form with the intent's fields" do
        intent = create(:search_intent, user: user)
        get new_search_path(from_intent: intent.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(intent.origin_airport)
        expect(response.body).to include(intent.destination_airport)
      end
    end

    context "with a from_intent belonging to another user" do
      it "returns 200 and renders a blank form (no error)" do
        other_intent = create(:search_intent, user: other_user)
        get new_search_path(from_intent: other_intent.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a non-existent from_intent id" do
      it "returns 200 and renders a blank form (no error, no alert)" do
        get new_search_path(from_intent: 999_999)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Search not found")
      end
    end

    context "without a from_intent param" do
      it "returns 200 and renders a blank form" do
        get new_search_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
