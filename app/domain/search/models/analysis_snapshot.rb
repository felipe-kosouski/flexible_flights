# frozen_string_literal: true

module Search
  module Models
    class AnalysisSnapshot
      attr_reader :price_p25_cents, :price_p50_cents, :price_p75_cents,
                  :route_median_duration_minutes, :volatility_index, :confidence_level

      def initialize(
        price_p25_cents: nil,
        price_p50_cents: nil,
        price_p75_cents: nil,
        route_median_duration_minutes: nil,
        volatility_index: nil,
        confidence_level: nil
      )
        @price_p25_cents              = price_p25_cents
        @price_p50_cents              = price_p50_cents
        @price_p75_cents              = price_p75_cents
        @route_median_duration_minutes = route_median_duration_minutes
        @volatility_index             = volatility_index
        @confidence_level             = confidence_level
      end

      def price_distribution_present?
        price_p25_cents && price_p50_cents && price_p75_cents
      end
    end
  end
end
