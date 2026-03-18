# frozen_string_literal: true

module Flights
  # Deterministic stub for tests and development.
  # Returns a fixed set of canonical flight hashes regardless of input.
  class Stub < Base
    def search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:, currency_code: "USD")
      [
        {
          price_cents: 15_000,
          currency: "EUR",
          airline_codes: [ "IB" ],
          stops: 0,
          air_time_minutes: 120,
          layover_time_minutes: 0,
          luggage_included: false,
          raw_provider: "stub"
        },
        {
          price_cents: 22_000,
          currency: "EUR",
          airline_codes: [ "VY", "FR" ],
          stops: 1,
          air_time_minutes: 180,
          layover_time_minutes: 60,
          luggage_included: true,
          raw_provider: "stub"
        }
      ]
    end
  end
end
