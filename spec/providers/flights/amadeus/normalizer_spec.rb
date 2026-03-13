# frozen_string_literal: true

require "rails_helper"
require "fixtures/amadeus/flight_offer"

RSpec.describe Flights::Amadeus::Normalizer do
  subject(:result) { described_class.call(offer) }

  let(:offer) { Fixtures::Amadeus::FLIGHT_OFFER }

  describe ".call" do
    it "returns a hash with all required canonical keys" do
      expected_keys = %i[price_cents currency airline_codes stops air_time_minutes
                         layover_time_minutes luggage_included raw_provider]
      expect(result.keys).to match_array(expected_keys)
    end

    describe "price_cents" do
      it "converts grandTotal string to integer cents" do
        expect(result[:price_cents]).to eq(23_456)
      end
    end

    describe "currency" do
      it "passes through the currency string" do
        expect(result[:currency]).to eq("EUR")
      end
    end

    describe "airline_codes" do
      it "returns unique carrier codes from the outbound itinerary only" do
        # Both outbound segments are VY; return is IB — only outbound included
        expect(result[:airline_codes]).to eq([ "VY" ])
      end
    end

    describe "stops" do
      it "sums stops across both itineraries" do
        # Outbound: 2 segments → 1 stop. Return: 1 segment → 0 stops. Total: 1.
        expect(result[:stops]).to eq(1)
      end
    end

    describe "air_time_minutes" do
      it "sums actual segment flight times across all legs" do
        # MAD→BCN: 70 min, BCN→LHR: 120 min, LHR→MAD: 210 min → 400 total
        expect(result[:air_time_minutes]).to eq(400)
      end
    end

    describe "layover_time_minutes" do
      it "equals total itinerary duration minus air time" do
        # Total duration: PT5H30M (330) + PT2H30M (150) = 480. Layover: 480 - 400 = 80.
        expect(result[:layover_time_minutes]).to eq(80)
      end
    end

    describe "luggage_included" do
      it "is true when any fare segment includes a checked bag" do
        # Third fareDetailsBySegment has quantity: 1
        expect(result[:luggage_included]).to be(true)
      end

      context "when no bags are included" do
        let(:offer) do
          Fixtures::Amadeus::FLIGHT_OFFER.merge(
            "travelerPricings" => [
              { "fareDetailsBySegment" => [
                { "includedCheckedBags" => { "quantity" => 0 } }
              ] }
            ]
          )
        end

        it "is false" do
          expect(result[:luggage_included]).to be(false)
        end
      end
    end

    describe "raw_provider" do
      it "is always 'amadeus'" do
        expect(result[:raw_provider]).to eq("amadeus")
      end
    end

    context "when the offer has malformed data" do
      let(:offer) { { "broken" => true } }

      it "returns nil instead of raising" do
        expect(result).to be_nil
      end
    end
  end

  describe "parse_iso_duration (via layover calculation)" do
    {
      "PT45M"     => 45,
      "PT1H"      => 60,
      "PT2H30M"   => 150,
      "P1DT3H"    => 1620,
      "P1DT2H30M" => 1590
    }.each do |iso, expected_minutes|
      it "parses #{iso} as #{expected_minutes} minutes" do
        # Build a minimal offer with a single direct segment and known total duration
        # so layover = total_duration - air_time = expected_minutes - air_time
        single_segment_offer = {
          "price"       => { "grandTotal" => "100.00", "currency" => "EUR" },
          "itineraries" => [
            {
              "duration" => iso,
              "segments" => [
                {
                  "carrierCode" => "IB",
                  "departure"   => { "iataCode" => "MAD", "at" => "2024-06-01T10:00:00" },
                  "arrival"     => { "iataCode" => "LHR", "at" => "2024-06-01T10:00:00" }
                }
              ]
            }
          ],
          "travelerPricings" => [
            { "fareDetailsBySegment" => [ { "includedCheckedBags" => { "quantity" => 0 } } ] }
          ]
        }
        # With a 0-minute segment (same departure and arrival), air_time = 0,
        # so layover_time = total_duration = expected_minutes
        r = described_class.call(single_segment_offer)
        expect(r[:layover_time_minutes]).to eq(expected_minutes)
      end
    end
  end
end
