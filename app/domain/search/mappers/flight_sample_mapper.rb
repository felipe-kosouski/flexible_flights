# frozen_string_literal: true

module Search
  module Mappers
    class FlightSampleMapper
      def self.map_all(raw_samples)
        raw_samples.filter_map { |raw| from_hash(raw) }
      end

      def self.from_hash(raw)
        return nil unless raw.is_a?(Hash)

        Models::FlightSample.new(
          price_cents: raw[:price_cents],
          stops: raw[:stops],
          air_time_minutes: raw[:air_time_minutes],
          layover_time_minutes: raw[:layover_time_minutes],
          departure_datetime: raw[:departure_datetime],
          return_datetime: raw[:return_datetime],
          luggage_included: raw[:luggage_included],
          currency: raw[:currency]
        )
      end
    end
  end
end
