# frozen_string_literal: true

module Search
  module Explanation
    class Builder
      VERSION = "1.0"

      MATERIALITY_THRESHOLD = 0.15
      STRONG_DEVIATION_THRESHOLD = 0.35
      LAYOVER_PENALTY = 1.3

      TRADEOFF_KEYS = {
        %i[price time_comfort] => :cheap_but_longer,
        %i[time_comfort price] => :fast_but_expensive
      }.freeze

      DIMENSION_STRENGTH_KEYS = {
        price: :strong_price,
        time_comfort: :strong_time_comfort,
        trip_fit: :strong_trip_fit
      }.freeze

      def self.call(flight:, intent:, snapshot:, score_result:)
        new(flight:, intent:, snapshot:, score_result:).call
      end

      def initialize(flight:, intent:, snapshot:, score_result:)
        @flight = flight
        @intent = intent
        @snapshot = snapshot
        @score_result = score_result
      end

      def call
        return nil unless valid_inputs?

        breakdown = build_score_breakdown
        return nil unless breakdown

        detected_tradeoffs = detect_tradeoffs
        explanation_summary = build_summary(breakdown, detected_tradeoffs)

        FlightExplanation.new(
          flight: flight,
          final_score: score_result.value,
          score_breakdown: breakdown,
          tradeoffs: detected_tradeoffs,
          summary: explanation_summary,
          baselines: build_baselines,
          metadata: { version: VERSION }
        )
      end

      private

      attr_reader :flight, :intent, :snapshot, :score_result

      def valid_inputs?
        score_result && flight && snapshot
      end

      def build_score_breakdown
        components = score_result.components
        return nil if components.values.any?(&:nil?)

        deviations = compute_baseline_deviations

        components.sort_by { |dim, _| dim }.map do |dimension, raw_score|
          weight = Scoring::FinalScore::WEIGHTS[dimension]
          {
            dimension: dimension,
            raw_score: raw_score,
            normalized_score: raw_score,
            weight: weight,
            weighted_contribution: raw_score * weight,
            relative_to_baseline: baseline_position(dimension, deviations)
          }
        end
      end

      def baseline_position(dimension, deviations)
        deviation = deviations[dimension]
        return :neutral unless deviation

        if deviation < -MATERIALITY_THRESHOLD
          :better
        elsif deviation > MATERIALITY_THRESHOLD
          :worse
        else
          :neutral
        end
      end

      def detect_tradeoffs
        deviations = compute_baseline_deviations
        return [] if deviations.size < 2

        gained = deviations.select { |_, dev| dev < -MATERIALITY_THRESHOLD }
        sacrificed = deviations.select { |_, dev| dev > MATERIALITY_THRESHOLD }

        tradeoffs = []
        gained.each do |gained_dim, gained_dev|
          sacrificed.each do |sac_dim, sac_dev|
            key = TRADEOFF_KEYS[[ gained_dim, sac_dim ]]
            next unless key

            tradeoffs << {
              gained_dimension: gained_dim,
              sacrificed_dimension: sac_dim,
              severity: compute_severity(gained_dev.abs, sac_dev.abs),
              explanation_key: key
            }
          end
        end

        tradeoffs.sort_by { |t| [ t[:gained_dimension], t[:sacrificed_dimension] ] }
      end

      def compute_baseline_deviations
        deviations = {}

        if price_baseline_available?
          deviations[:price] = (flight.price_cents - snapshot.price_p50_cents).to_f / snapshot.price_p50_cents
        end

        if duration_baseline_available?
          effective = flight.air_time_minutes + (flight.layover_time_minutes * LAYOVER_PENALTY)
          deviations[:time_comfort] = (effective - snapshot.route_median_duration_minutes).to_f / snapshot.route_median_duration_minutes
        end

        deviations
      end

      def price_baseline_available?
        snapshot.price_p50_cents && snapshot.price_p50_cents > 0 && flight.price_cents
      end

      def duration_baseline_available?
        snapshot.route_median_duration_minutes && snapshot.route_median_duration_minutes > 0 &&
          flight.air_time_minutes && flight.layover_time_minutes
      end

      def compute_severity(gained_magnitude, sacrificed_magnitude)
        if gained_magnitude >= STRONG_DEVIATION_THRESHOLD && sacrificed_magnitude >= STRONG_DEVIATION_THRESHOLD
          :high
        elsif gained_magnitude >= STRONG_DEVIATION_THRESHOLD || sacrificed_magnitude >= STRONG_DEVIATION_THRESHOLD
          :medium
        else
          :low
        end
      end

      def build_summary(breakdown, tradeoffs)
        sorted = breakdown.sort_by { |entry| -entry[:weighted_contribution] }
        primary = [ sorted.first[:dimension] ]
        secondary = sorted.drop(1).map { |entry| entry[:dimension] }

        keys = primary.filter_map { |dim| DIMENSION_STRENGTH_KEYS[dim] }
        keys.concat(tradeoffs.map { |t| t[:explanation_key] })

        {
          primary_factors: primary,
          secondary_factors: secondary,
          explanation_keys: keys
        }
      end

      def build_baselines
        {
          price_median_cents: snapshot.price_p50_cents,
          duration_median_minutes: snapshot.route_median_duration_minutes,
          volatility: snapshot.volatility,
          confidence: snapshot.confidence
        }
      end
    end
  end
end
