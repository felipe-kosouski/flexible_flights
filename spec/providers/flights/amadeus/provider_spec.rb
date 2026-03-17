# frozen_string_literal: true

require "rails_helper"
require "fixtures/amadeus/flight_offer"

RSpec.describe Flights::Amadeus::Provider do
  subject(:provider) { described_class.new }

  let(:base_url) { "https://test.api.amadeus.com" }
  let(:token_url) { "#{base_url}/v1/security/oauth2/token" }
  let(:offers_url) { "#{base_url}/v2/shopping/flight-offers" }
  let(:token_response) do
    { "access_token" => "token", "expires_in" => 1799 }.to_json
  end

  before do
    allow(ENV).to receive(:fetch).with("AMADEUS_CLIENT_ID").and_return("id")
    allow(ENV).to receive(:fetch).with("AMADEUS_CLIENT_SECRET").and_return("secret")
    allow(ENV).to receive(:fetch).with("AMADEUS_ENV", "test").and_return("test")

    stub_request(:post, token_url)
      .to_return(status: 200, body: token_response, headers: { "Content-Type" => "application/json" })
  end

  describe "#search" do
    let(:departure_date) { Date.new(2024, 6, 1) }
    let(:return_date) { Date.new(2024, 6, 8) }

    context "when the API returns valid offers" do
      before do
        stub_get(offers_url)
          .to_return(
            status: 200,
            body: { "data" => [ Fixtures::Amadeus::FLIGHT_OFFER ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns an array of normalized flight hashes" do
        results = provider.search(
          origin: "MAD", destination: "LHR",
          departure_date: departure_date, return_date: return_date,
          passengers: 1, cabin_class: :economy
        )
        expect(results).to be_an(Array)
        expect(results.size).to eq(1)
      end

      it "passes the correct parameters to the Amadeus API" do
        provider.search(
          origin: "MAD", destination: "LHR",
          departure_date: departure_date, return_date: return_date,
          passengers: 1, cabin_class: :economy
        )

        expect(WebMock).to have_requested(:get, offers_url).with(
          query: hash_including(
            "originLocationCode" => "MAD",
            "destinationLocationCode" => "LHR",
            "departureDate" => "2024-06-01",
            "returnDate" => "2024-06-08",
            "adults" => "1",
            "travelClass" => "ECONOMY"
          )
        )
      end

      it "produces normalized hashes that satisfy Sampler::REQUIRED_KEYS" do
        results = provider.search(
          origin: "MAD", destination: "LHR",
          departure_date: departure_date, return_date: return_date,
          passengers: 1, cabin_class: :economy
        )
        required_keys = Search::Sampling::Sampler::REQUIRED_KEYS
        results.each do |flight|
          expect(flight.keys).to include(*required_keys)
        end
      end
    end

    context "when the API returns an empty data array" do
      before do
        stub_get(offers_url)
          .to_return(status: 200, body: { "data" => [] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns an empty array" do
        results = provider.search(
          origin: "MAD", destination: "LHR",
          departure_date: departure_date, return_date: return_date,
          passengers: 1, cabin_class: :economy
        )
        expect(results).to eq([])
      end
    end

    context "when an offer fails normalization" do
      before do
        stub_get(offers_url)
          .to_return(
            status: 200,
            body: { "data" => [ { "broken" => true }, Fixtures::Amadeus::FLIGHT_OFFER ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "silently drops the invalid offer and returns the valid ones" do
        results = provider.search(
          origin: "MAD", destination: "LHR",
          departure_date: departure_date, return_date: return_date,
          passengers: 1, cabin_class: :economy
        )
        expect(results.size).to eq(1)
        expect(results.first[:raw_provider]).to eq("amadeus")
      end
    end
  end
end
