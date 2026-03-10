# frozen_string_literal: true

module Flights
  class Base
    # Subclasses must implement this method.
    #
    # Returns Array<Hash> where each hash contains the canonical flight fields:
    #   price_cents, currency, airline_codes, stops, air_time_minutes,
    #   layover_time_minutes, luggage_included, raw_provider
    def search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
      raise NotImplementedError, "#{self.class}#search is not implemented"
    end
  end
end
