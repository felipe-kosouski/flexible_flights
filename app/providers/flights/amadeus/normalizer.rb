# frozen_string_literal: true

module Flights
  module Amadeus
    class Normalizer
      PROVIDER_NAME = "amadeus"

      def self.call(offer)
        new(offer).call
      end

      def initialize(offer)
        @offer = offer
      end

      def call
        validate!
        {
          price_cents: price_cents,
          currency: currency,
          airline_codes: airline_codes,
          stops: stops,
          air_time_minutes: air_time_minutes,
          layover_time_minutes: layover_time_minutes,
          luggage_included: luggage_included,
          raw_provider: PROVIDER_NAME
        }
      rescue StandardError
        nil
      end

      private

      def validate!
        raise ArgumentError, "Missing price" unless @offer.dig("price", "grandTotal")
        raise ArgumentError, "Missing itineraries" if itineraries.empty?
        raise ArgumentError, "Missing segments" if all_segments.empty?
      end

      def price_cents
        (@offer.dig("price", "grandTotal").to_f * 100).round
      end

      def currency
        @offer.dig("price", "currency")
      end

      def airline_codes
        outbound_segments.map { |s| s["carrierCode"] }.uniq
      end

      def stops
        itineraries.sum { |itin| itin["segments"].size - 1 }
      end

      # Sum of each segment's actual flight time (arrival minus departure).
      def air_time_minutes
        all_segments.sum do |segment|
          departure = Time.parse(segment.dig("departure", "at"))
          arrival   = Time.parse(segment.dig("arrival", "at"))
          ((arrival - departure) / 60).round
        end
      end

      # Total itinerary duration minus actual airborne time = layover time.
      def layover_time_minutes
        total = itineraries.sum { |itin| parse_iso_duration(itin["duration"]) }
        [ total - air_time_minutes, 0 ].max
      end

      def luggage_included
        segments = @offer.dig("travelerPricings", 0, "fareDetailsBySegment") || []
        segments.any? { |s| s.dig("includedCheckedBags", "quantity").to_i > 0 }
      end

      def itineraries
        @offer["itineraries"] || []
      end

      def outbound_segments
        (itineraries.first || {}).fetch("segments", [])
      end

      def all_segments
        itineraries.flat_map { |itin| itin["segments"] || [] }
      end

      # Parses ISO 8601 duration strings into minutes.
      # Handles: PT2H30M, PT45M, PT1H, P1DT3H, P1DT2H30M
      def parse_iso_duration(iso)
        return 0 if iso.nil?

        days = iso[/(\d+)D/, 1].to_i
        hours = iso[/(\d+)H/, 1].to_i
        minutes = iso[/(\d+)M/, 1].to_i
        days * 1440 + hours * 60 + minutes
      end
    end
  end
end
