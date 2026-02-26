# frozen_string_literal: true

module Search
  module Analysis
    class SnapshotBuilder
      LAYOVER_PENALTY = 1.3

      def self.build(flight_samples)
        new(flight_samples).build
      end

      def initialize(flight_samples)
        @samples = Array(flight_samples)
      end

      def build
        return nil if @samples.empty?
        return nil if valid_prices.empty?
        return nil if valid_durations.empty?

        p25 = percentile(valid_prices, 0.25)
        p50 = percentile(valid_prices, 0.50)
        p75 = percentile(valid_prices, 0.75)
        vol = volatility_category(p25, p50, p75)
        conf = confidence_category(@samples.size, vol)

        Search::Models::AnalysisSnapshot.new(
          price_p25_cents: p25,
          price_p50_cents: p50,
          price_p75_cents: p75,
          route_median_duration_minutes: percentile(valid_durations, 0.50),
          sample_count: @samples.size,
          volatility: vol,
          confidence: conf
        )
      end

      private

      def valid_prices
        @valid_prices ||= @samples.map(&:price_cents).select { |price| price && price > 0 }.sort
      end

      def valid_durations
        @valid_durations ||= @samples
          .select { |s| s.air_time_minutes && s.layover_time_minutes }
          .map { |s| s.air_time_minutes + (s.layover_time_minutes * LAYOVER_PENALTY) }
          .sort
      end

      def percentile(sorted, p)
        sorted[((sorted.size - 1) * p).floor]
      end

      def volatility_category(p25, p50, p75)
        ratio = (p75 - p25).to_f / p50
        case ratio
        when 0.0..0.20
          :low
        when 0.20..0.40
          :medium
        else
          :high
        end
      end

      # Dominance order:
      # 1. Insufficient samples → low
      # 2. High volatility → low
      # 3. Large sample + low volatility → high
      # 4. Otherwise → medium
      def confidence_category(count, volatility)
        return :low if count < 10

        return :low if volatility == :high

        return :high if count >= 20 && volatility == :low

        :medium
      end
    end
  end
end
