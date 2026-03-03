# frozen_string_literal: true

module Search
  module Insights
    class Builder
      BALANCED_SCORE_THRESHOLD = 70

      def self.call(ranked_flights:, snapshot:, intent:)
        new(ranked_flights:, snapshot:, intent:).call
      end

      def initialize(ranked_flights:, snapshot:, intent:)
        @ranked_flights = ranked_flights
        @snapshot = snapshot
        @intent = intent
      end

      def call
        return nil if @snapshot.nil? || @ranked_flights.nil?

        SearchInsights.new(
          best_time_to_travel: build_best_time_to_travel,
          wait_or_book: build_wait_or_book,
          price_rarity: build_price_rarity,
          cheapest_comfort_window: build_cheapest_comfort_window,
          confidence_level: @snapshot.confidence
        )
      end

      private

      attr_reader :ranked_flights, :snapshot, :intent

      def build_best_time_to_travel
        return nil if snapshot.confidence == :low
        return nil if ranked_flights.empty?

        buckets = ranked_flights.group_by { |rf| week_key(rf.flight.departure_datetime) }
        qualifying = buckets.select { |_, flights| flights.size >= 2 }
        return nil if qualifying.empty?

        _, winning_flights = qualifying.min_by do |key, flights|
          avg = average_score(flights)
          [ -avg, week_sort_value(key) ]
        end

        dates = winning_flights.map { |rf| rf.flight.departure_datetime.to_date }

        DateRangeInsight.new(
          from_date: dates.min,
          to_date: dates.max,
          average_score: average_score(winning_flights),
          flight_count: winning_flights.size,
          confidence_level: snapshot.confidence
        )
      end

      def build_wait_or_book
        if snapshot.confidence == :low
          return insufficient_data_directive
        end

        if ranked_flights.empty? || !snapshot.price_distribution_present?
          return insufficient_data_directive
        end

        top_prices = ranked_flights.first(3).map { |rf| rf.flight.price_cents }
        top_median = compute_median(top_prices)
        band = price_band(top_median)
        directive = compute_directive(band)

        WaitOrBookInsight.new(
          directive: directive,
          price_band: band,
          top_flight_median_price_cents: top_median,
          confidence_level: snapshot.confidence
        )
      end

      def build_price_rarity
        return nil if snapshot.confidence == :low
        return nil if ranked_flights.empty?
        return nil unless snapshot.price_distribution_present?

        all_prices = ranked_flights.map { |rf| rf.flight.price_cents }
        market_price = compute_median(all_prices)

        PriceRarityInsight.new(
          classification: price_band_to_rarity(price_band(market_price)),
          market_representative_price_cents: market_price,
          confidence_level: snapshot.confidence
        )
      end

      def build_cheapest_comfort_window
        return nil if snapshot.confidence == :low

        balanced = ranked_flights.select do |rf|
          rf.score_result.components[:price] >= BALANCED_SCORE_THRESHOLD &&
            rf.score_result.components[:time_comfort] >= BALANCED_SCORE_THRESHOLD
        end

        return nil if balanced.size < 2

        dates = balanced.map { |rf| rf.flight.departure_datetime.to_date }

        DateRangeInsight.new(
          from_date: dates.min,
          to_date: dates.max,
          average_score: average_score(balanced),
          flight_count: balanced.size,
          confidence_level: snapshot.confidence
        )
      end

      def compute_directive(band)
        return :wait if snapshot.volatility == :high
        return :book_now if snapshot.confidence == :high && band == :cheap
        return :consider_booking if %i[cheap below_median].include?(band) && snapshot.confidence == :medium
        return :consider_booking if band == :below_median && snapshot.confidence == :high

        :wait
      end

      def price_band(price_cents)
        if price_cents <= snapshot.price_p25_cents
          :cheap
        elsif price_cents <= snapshot.price_p50_cents
          :below_median
        elsif price_cents <= snapshot.price_p75_cents
          :above_median
        else
          :expensive
        end
      end

      def price_band_to_rarity(band)
        band == :cheap ? :rare_cheap : band
      end

      def compute_median(values)
        sorted = values.sort
        n = sorted.size
        mid = n / 2
        n.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0).round
      end

      def average_score(flights)
        flights.sum { |rf| rf.score_result.value } / flights.size.to_f
      end

      def week_key(datetime)
        date = datetime.to_date
        "#{date.cwyear}-#{format('%02d', date.cweek)}"
      end

      def week_sort_value(key)
        year, week = key.split("-").map(&:to_i)
        year * 100 + week
      end

      def insufficient_data_directive
        WaitOrBookInsight.new(
          directive: :insufficient_data,
          price_band: nil,
          top_flight_median_price_cents: nil,
          confidence_level: snapshot.confidence
        )
      end
    end
  end
end
