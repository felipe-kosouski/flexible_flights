# frozen_string_literal: true

# Minimal but realistic Amadeus Flight Offers Search v2 response payload.
# Represents a round-trip MAD → LHR with one stop on the outbound leg.
module Fixtures
  module Amadeus
    FLIGHT_OFFER = {
      "id" => "1",
      "price" => {
        "currency" => "EUR",
        "grandTotal" => "234.56"
      },
      "itineraries" => [
        {
          # Outbound: MAD → BCN → LHR (1 stop, 2 segments)
          "duration" => "PT5H30M",
          "segments" => [
            {
              "carrierCode" => "VY",
              "departure" => { "iataCode" => "MAD", "at" => "2024-06-01T07:00:00" },
              "arrival" => { "iataCode" => "BCN", "at" => "2024-06-01T08:10:00" },
              "numberOfStops" => 0
            },
            {
              "carrierCode" => "VY",
              "departure" => { "iataCode" => "BCN", "at" => "2024-06-01T09:30:00" },
              "arrival" => { "iataCode" => "LHR", "at" => "2024-06-01T11:30:00" },
              "numberOfStops" => 0
            }
          ]
        },
        {
          # Return: LHR → MAD (direct, 1 segment)
          "duration" => "PT2H30M",
          "segments" => [
            {
              "carrierCode" => "IB",
              "departure" => { "iataCode" => "LHR", "at" => "2024-06-08T14:00:00" },
              "arrival" => { "iataCode" => "MAD", "at" => "2024-06-08T17:30:00" },
              "numberOfStops" => 0
            }
          ]
        }
      ],
      "travelerPricings" => [
        {
          "fareDetailsBySegment" => [
            { "includedCheckedBags" => { "quantity" => 0 } },
            { "includedCheckedBags" => { "quantity" => 0 } },
            { "includedCheckedBags" => { "quantity" => 1 } }
          ]
        }
      ]
    }.freeze
  end
end
