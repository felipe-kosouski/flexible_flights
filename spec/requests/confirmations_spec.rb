# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Email confirmation flow", type: :request do
  describe "POST /users (sign up)" do
    it "redirects to check-email page after sign-up" do
      post user_registration_path, params: {
        user: {
          email: "new@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
      expect(response).to redirect_to(check_email_path)
    end

    it "stores the email in flash for the check-email page" do
      post user_registration_path, params: {
        user: {
          email: "new@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
      follow_redirect!
      expect(response.body).to include("new@example.com")
    end
  end

  describe "GET /check-email" do
    it "returns 200" do
      get check_email_path
      expect(response).to have_http_status(:ok)
    end

    it "includes a link to resend confirmation" do
      get check_email_path
      expect(response.body).to include(new_user_confirmation_path)
    end
  end

  describe "GET /users/confirmation/new" do
    it "returns 200" do
      get new_user_confirmation_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "confirmed user sign-in" do
    it "signs in a confirmed user successfully" do
      user = create(:user) # confirmed_at set by factory
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      expect(response).to redirect_to(new_search_path)
    end
  end

  describe "unconfirmed user sign-in" do
    it "blocks sign-in and shows an error" do
      user = create(:user, confirmed_at: nil)
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      expect(response).not_to redirect_to(new_search_path)
    end
  end

  describe "welcome email on confirmation" do
    it "enqueues a welcome email when a valid token is confirmed" do
      user = create(:user, confirmed_at: nil)
      raw_token, hashed = Devise.token_generator.generate(User, :confirmation_token)
      user.update_columns(confirmation_token: hashed, confirmation_sent_at: 1.hour.ago)
      expect {
        get user_confirmation_path, params: { confirmation_token: raw_token }
      }.to have_enqueued_mail(UserMailer, :welcome).with(user)
    end

    it "does not enqueue a welcome email for an invalid token" do
      expect {
        get user_confirmation_path, params: { confirmation_token: "badtoken" }
      }.not_to have_enqueued_mail(UserMailer, :welcome)
    end
  end
end
