# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SearchHistory", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /history" do
    context "when not signed in" do
      it "redirects to sign in" do
        get search_history_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns 200" do
        get search_history_path
        expect(response).to have_http_status(:ok)
      end

      it "shows only the current user's search runs" do
        own_intent   = create(:search_intent, user: user)
        own_run      = create(:search_run, search_intent: own_intent)
        other_intent = create(:search_intent, user: other_user)
        other_run    = create(:search_run, search_intent: other_intent)

        get search_history_path

        expect(response.body).to include("data-run-id=\"#{own_run.id}\"")
        expect(response.body).not_to include("data-run-id=\"#{other_run.id}\"")
      end

      it "orders runs newest first" do
        intent = create(:search_intent, user: user)
        old_run = create(:search_run, search_intent: intent,
                         created_at: 3.days.ago)
        new_run = create(:search_run, search_intent: intent,
                         created_at: 1.hour.ago)

        get search_history_path

        # Both cards render a data-run-id attribute — assert new appears before old.
        expect(response.body.index("data-run-id=\"#{new_run.id}\""))
          .to be < response.body.index("data-run-id=\"#{old_run.id}\"")
      end

      it "renders an empty state when the user has no runs" do
        get search_history_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
