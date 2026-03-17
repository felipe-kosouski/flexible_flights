# frozen_string_literal: true

module Search
  module Scoring
    class PriceScore
      CHEAP_SCORE = 100
      BELOW_MEDIAN_SCORE = 80
      ABOVE_MEDIAN_SCORE = 50
      EXPENSIVE_SCORE = 20

      def self.call(flight_sample:, analysis_snapshot:)
        new(flight_sample, analysis_snapshot).score
      end

      def initialize(flight_sample, analysis_snapshot)
        @flight = flight_sample
        @snapshot = analysis_snapshot
      end

      def score
        return nil unless inputs_valid?

        if cheap?
          CHEAP_SCORE
        elsif below_median?
          BELOW_MEDIAN_SCORE
        elsif above_median?
          ABOVE_MEDIAN_SCORE
        else
          EXPENSIVE_SCORE
        end
      end

      private

      attr_reader :flight, :snapshot

      def inputs_valid?
        flight.price_cents && snapshot.price_distribution_present?
      end

      def cheap?
        flight.price_cents <= snapshot.price_p25_cents
      end

      def below_median?
        flight.price_cents <= snapshot.price_p50_cents
      end

      def above_median?
        flight.price_cents <= snapshot.price_p75_cents
      end
    end
  end
end
