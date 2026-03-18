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
        creds = Rails.application.credentials.amadeus!
        @client = Client.new(
          client_id: creds.client_id!,
          client_secret: creds.client_secret!,
          env: Rails.env.production? ? :production : :test
        )
      end

      def search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:, currency_code: "USD")
        raw = @client.flight_offers(
          originLocationCode: origin,
          destinationLocationCode: destination,
          departureDate: departure_date.iso8601,
          returnDate: return_date.iso8601,
          adults: passengers,
          travelClass: CABIN_CLASS_MAP.fetch(cabin_class),
          currencyCode: currency_code,
          max: MAX_RESULTS
        )

        (raw["data"] || []).filter_map { |offer| Normalizer.call(offer) }
      end
    end
  end
end
