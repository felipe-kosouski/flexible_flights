# frozen_string_literal: true

module Search
  module Factories
    class AnalysisSnapshotFactory
      def self.from_record(record)
        return nil unless record

        Models::AnalysisSnapshot.new(
          price_p25_cents: record.price_p25_cents,
          price_p50_cents: record.price_p50_cents,
          price_p75_cents: record.price_p75_cents,
          route_median_duration_minutes: record.route_median_duration_minutes,
          sample_count: record.sample_count,
          confidence: record.confidence_level.to_sym,
          volatility: record.volatility.to_sym
        )
      end
    end
  end
end
