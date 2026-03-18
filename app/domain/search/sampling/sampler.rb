# frozen_string_literal: true

module Search
  module Sampling
    class Sampler
      REQUIRED_KEYS = %i[
        price_cents
        currency
        airline_codes
        stops
        air_time_minutes
        layover_time_minutes
        luggage_included
        raw_provider
      ].freeze

      def initialize(origin:, destination:, date_pairs:, passengers: 1, cabin_class: :economy, provider:, currency_code: "USD")
        @origin = origin
        @destination = destination
        @date_pairs = date_pairs
        @passengers = passengers
        @cabin_class = cabin_class
        @provider = provider
        @currency_code = currency_code
      end

      def call
        samples = []

        @date_pairs.each do |departure_date, return_date|
          results = fetch_results(departure_date, return_date)

          unless results.is_a?(Array)
            raise TypeError, "Provider must return an Array, got #{results.class}"
          end

          results.each do |raw_result|
            normalized = normalize(raw_result, departure_date, return_date)
            samples << normalized if normalized
          end
        end

        dedup(samples)
      end

      private

      def fetch_results(departure_date, return_date)
        @provider.search(
          origin: @origin,
          destination: @destination,
          departure_date: departure_date,
          return_date: return_date,
          passengers: @passengers,
          cabin_class: @cabin_class,
          currency_code: @currency_code
        )
      end

      def normalize(raw_sample, departure_date, return_date)
        return nil unless valid_sample?(raw_sample)

        raw_sample.merge(
          departure_datetime: departure_date.to_time,
          return_datetime: return_date.to_time
        )
      end

      def valid_sample?(raw_sample)
        return false unless raw_sample.is_a?(Hash)

        REQUIRED_KEYS.all? do |key|
          raw_sample.key?(key) && !raw_sample[key].nil?
        end
      end

      def dedup(samples)
        seen = {}
        samples.each_with_object([]) do |s, unique|
          key = [
            s[:price_cents],
            s[:departure_datetime],
            s[:return_datetime],
            s[:stops],
            s[:air_time_minutes],
            s[:layover_time_minutes]
          ]
          unique << s unless seen.key?(key)
          seen[key] = true
        end
      end
    end
  end
end
