# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rack::Attack throttling", type: :request do
  before do
    @original_store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @original_store
  end

  describe "logins/ip — 10 requests per 20 seconds per IP" do
    it "allows up to 10 login attempts then blocks with 429" do
      10.times do |i|
        post user_session_path, params: { user: { email: "ip_test#{i}@example.com", password: "wrong" } }
        expect(response.status).not_to eq(429)
      end

      post user_session_path, params: { user: { email: "ip_test10@example.com", password: "wrong" } }
      expect(response.status).to eq(429)
    end
  end

  describe "logins/email — 5 requests per 20 seconds per email" do
    it "allows up to 5 login attempts per email then blocks with 429" do
      5.times do
        post user_session_path, params: { user: { email: "target@example.com", password: "wrong" } }
        expect(response.status).not_to eq(429)
      end

      post user_session_path, params: { user: { email: "target@example.com", password: "wrong" } }
      expect(response.status).to eq(429)
    end

    it "counts different emails separately" do
      5.times do
        post user_session_path, params: { user: { email: "target@example.com", password: "wrong" } }
      end

      # Different email should not be throttled yet
      post user_session_path, params: { user: { email: "other@example.com", password: "wrong" } }
      expect(response.status).not_to eq(429)
    end
  end

  describe "signups/ip — 5 requests per 60 seconds per IP" do
    it "allows up to 5 signup attempts then blocks with 429" do
      5.times do |i|
        post user_registration_path, params: {
          user: {
            email: "new#{i}@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
        expect(response.status).not_to eq(429)
      end

      post user_registration_path, params: {
        user: {
          email: "overflow@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
      expect(response.status).to eq(429)
    end
  end

  describe "searches/user — 3 requests per 60 seconds per user" do
    let(:user) { create(:user) }
    let(:search_params) do
      {
        search_intent: {
          origin_airport: "GRU",
          destination_airport: "LIS",
          flexible_days: 7,
          trip_duration: 14,
          adults: 1,
          max_stops: 1,
          budget: 1500
        }
      }
    end

    before { sign_in user }

    it "allows up to 3 search submissions then blocks with 429" do
      3.times do
        post searches_path, params: search_params
        expect(response.status).not_to eq(429)
      end

      post searches_path, params: search_params
      expect(response.status).to eq(429)
    end

    it "counts different users separately" do
      other_user = create(:user)

      3.times { post searches_path, params: search_params }
      post searches_path, params: search_params
      expect(response.status).to eq(429) # confirms user IS throttled

      # Switch to a different user — their counter should be independent
      sign_in other_user
      post searches_path, params: search_params
      expect(response.status).not_to eq(429)
    end
  end
end
