# frozen_string_literal: true

module Search
  module Models
    class AnalysisSnapshot
      attr_reader :price_p25_cents, :price_p50_cents, :price_p75_cents,
                  :route_median_duration_minutes, :sample_count,
                  :volatility, :confidence

      def initialize(
        price_p25_cents: nil,
        price_p50_cents: nil,
        price_p75_cents: nil,
        route_median_duration_minutes: nil,
        sample_count: nil,
        volatility: nil,
        confidence: nil
      )
        @price_p25_cents = price_p25_cents
        @price_p50_cents = price_p50_cents
        @price_p75_cents = price_p75_cents
        @route_median_duration_minutes = route_median_duration_minutes
        @sample_count = sample_count
        @volatility = volatility
        @confidence = confidence
      end

      def price_distribution_present?
        !price_p25_cents.nil? && !price_p50_cents.nil? && !price_p75_cents.nil?
      end
    end
  end
end
