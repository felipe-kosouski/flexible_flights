# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profile", type: :request do
  let(:user) { create(:user, first_name: "Jane", last_name: "Doe", email: "jane@example.com", password: "password123") }

  describe "authentication guard" do
    it "redirects GET /profile to sign in when not signed in" do
      get profile_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects PATCH /profile to sign in when not signed in" do
      patch profile_path, params: { form_type: "personal_info", user: { email: "x@example.com" } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects DELETE /profile to sign in when not signed in" do
      delete profile_path, params: { confirmation_email: "jane@example.com" }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /profile" do
    before { sign_in user }

    it "returns 200" do
      get profile_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the user display name as the page heading" do
      get profile_path
      expect(response.body).to include("Jane Doe")
    end
  end

  describe "PATCH /profile — personal_info" do
    before { sign_in user }

    context "with valid params" do
      it "updates the user and redirects to profile_path" do
        patch profile_path, params: {
          form_type: "personal_info",
          user: { first_name: "John", last_name: "Smith", email: "john@example.com" }
        }
        expect(response).to redirect_to(profile_path)
        follow_redirect!
        expect(response.body).to include("John Smith")
      end
    end

    context "with invalid params (blank email)" do
      it "re-renders the profile form with status 422" do
        patch profile_path, params: {
          form_type: "personal_info",
          user: { first_name: "Jane", last_name: "Doe", email: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /profile — password" do
    before { sign_in user }

    context "with correct current password and a valid new password" do
      it "updates the password and redirects to profile_path" do
        patch profile_path, params: {
          form_type: "password",
          user: { current_password: "password123", password: "newpassword456", password_confirmation: "newpassword456" }
        }
        expect(response).to redirect_to(profile_path)
      end

      it "keeps the user signed in after updating the password" do
        patch profile_path, params: {
          form_type: "password",
          user: { current_password: "password123", password: "newpassword456", password_confirmation: "newpassword456" }
        }
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end
    end

    context "with wrong current password" do
      it "re-renders the profile form with status 422" do
        patch profile_path, params: {
          form_type: "password",
          user: { current_password: "wrongpassword", password: "newpassword456", password_confirmation: "newpassword456" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with mismatched password confirmation" do
      it "re-renders the profile form with status 422" do
        patch profile_path, params: {
          form_type: "password",
          user: { current_password: "password123", password: "newpassword456", password_confirmation: "different999" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /profile — unknown form_type" do
    before { sign_in user }

    it "redirects to profile_path with an alert" do
      patch profile_path, params: { form_type: "unknown" }
      expect(response).to redirect_to(profile_path)
      follow_redirect!
      expect(response.body).to include("Invalid request")
    end
  end

  describe "DELETE /profile" do
    before { sign_in user }

    context "when confirmation email matches (case-insensitive)" do
      it "destroys the account and redirects to root_path" do
        delete profile_path, params: { confirmation_email: "jane@example.com" }
        expect(response).to redirect_to(root_path)
        expect(User.exists?(user.id)).to be false
      end

      it "invalidates the session so subsequent authenticated requests redirect to sign in" do
        delete profile_path, params: { confirmation_email: "jane@example.com" }
        get profile_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when confirmation email does not match" do
      it "redirects to profile_path with an alert and preserves the account" do
        delete profile_path, params: { confirmation_email: "wrong@example.com" }
        expect(response).to redirect_to(profile_path)
        expect(User.exists?(user.id)).to be true
      end
    end
  end
end
