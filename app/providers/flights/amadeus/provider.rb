# frozen_string_literal: true

module Flights
  module Amadeus
    class Provider < Flights::Base
      CABIN_CLASS_MAP = {
        economy: "ECONOMY",
        business: "BUSINESS",
        first: "FIRST"
      }.freeze

      MAX_RESULTS = 10

      def initialize
        @client = Client.new(
          client_id: ENV.fetch("AMADEUS_CLIENT_ID"),
          client_secret: ENV.fetch("AMADEUS_CLIENT_SECRET"),
          env: ENV.fetch("AMADEUS_ENV", "test").to_sym
        )
      end

      def search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
        raw = @client.flight_offers(
          originLocationCode: origin,
          destinationLocationCode: destination,
          departureDate: departure_date.iso8601,
          returnDate: return_date.iso8601,
          adults: passengers,
          travelClass: CABIN_CLASS_MAP.fetch(cabin_class),
          max: MAX_RESULTS
        )

        (raw["data"] || []).filter_map { |offer| Normalizer.call(offer) }
      end
    end
  end
end
