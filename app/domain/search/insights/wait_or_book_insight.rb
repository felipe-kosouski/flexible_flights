# frozen_string_literal: true

module Search
  module Insights
    class WaitOrBookInsight
      attr_reader :directive, :price_band, :top_flight_median_price_cents, :confidence_level

      def initialize(directive:, price_band:, top_flight_median_price_cents:, confidence_level:)
        @directive = directive
        @price_band = price_band
        @top_flight_median_price_cents = top_flight_median_price_cents
        @confidence_level = confidence_level
        freeze
      end
    end
  end
end
