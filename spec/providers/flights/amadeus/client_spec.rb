# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flights::Amadeus::Client do
  subject(:client) do
    described_class.new(client_id: "test_id", client_secret: "test_secret", env: :test)
  end

  let(:base_url) { "https://test.api.amadeus.com" }
  let(:token_url) { "#{base_url}/v1/security/oauth2/token" }
  let(:offers_url) { "#{base_url}/v2/shopping/flight-offers" }
  let(:valid_token) { "test_access_token" }
  let(:token_response) do
    { "access_token" => valid_token, "expires_in" => 1799 }.to_json
  end

  def stub_token
    stub_request(:post, token_url)
      .to_return(status: 200, body: token_response, headers: { "Content-Type" => "application/json" })
  end

  describe "#flight_offers" do
    context "with a valid token" do
      before { stub_token }

      it "fetches and returns the flight offers data" do
        offers_body = { "data" => [ { "id" => "1" } ] }.to_json
        stub_get(offers_url)
          .with(headers: { "Authorization" => "Bearer #{valid_token}" })
          .to_return(status: 200, body: offers_body, headers: { "Content-Type" => "application/json" })

        result = client.flight_offers(originLocationCode: "MAD", destinationLocationCode: "LHR")
        expect(result["data"].first["id"]).to eq("1")
      end

      it "caches the token and does not re-authenticate on subsequent calls" do
        stub_request(:get, offers_url).to_return(
          status: 200, body: { "data" => [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

        client.flight_offers({})
        client.flight_offers({})

        expect(WebMock).to have_requested(:post, token_url).once
      end
    end

    context "when the API returns 429" do
      before { stub_token }

      it "raises Flights::RateLimitError" do
        stub_request(:get, offers_url).to_return(status: 429, body: "", headers: {})

        expect { client.flight_offers({}) }.to raise_error(Flights::RateLimitError)
      end
    end

    context "when the API returns 401" do
      before { stub_token }

      it "raises Flights::AuthError" do
        stub_request(:get, offers_url).to_return(status: 401, body: "", headers: {})

        expect { client.flight_offers({}) }.to raise_error(Flights::AuthError)
      end
    end

    context "when the request times out" do
      before { stub_token }

      it "raises Flights::TimeoutError" do
        stub_request(:get, offers_url).to_timeout

        expect { client.flight_offers({}) }.to raise_error(Flights::TimeoutError)
      end
    end

    context "when the token request fails" do
      it "raises Flights::AuthError" do
        stub_request(:post, token_url).to_return(status: 401, body: "", headers: {})

        expect { client.flight_offers({}) }.to raise_error(Flights::AuthError)
      end
    end
  end
end
