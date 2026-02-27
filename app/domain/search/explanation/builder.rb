# frozen_string_literal: true

module Search
  module Explanation
    class Builder
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

      def self.call(flight:, intent:, snapshot:, final_score:)
        new(flight:, intent:, snapshot:, final_score:).call
      end

      def initialize(flight:, intent:, snapshot:, final_score:)
        @flight = flight
        @intent = intent
        @snapshot = snapshot
        @final_score = final_score
      end

      def call
        return nil unless valid_inputs?

        breakdown = build_score_breakdown
        return nil unless breakdown

        detected_tradeoffs = detect_tradeoffs
        explanation_summary = build_summary(breakdown, detected_tradeoffs)

        FlightExplanation.new(
          flight: flight,
          score_breakdown: breakdown,
          tradeoffs: detected_tradeoffs,
          summary: explanation_summary
        )
      end

      private

      attr_reader :flight, :intent, :snapshot, :final_score

      def valid_inputs?
        final_score && flight && snapshot
      end

      def build_score_breakdown
        components = compute_component_scores
        return nil if components.values.any?(&:nil?)

        components.sort_by { |dim, _| dim }.map do |dimension, raw_score|
          weight = Scoring::FinalScore::WEIGHTS[dimension]
          {
            dimension: dimension,
            raw_score: raw_score,
            normalized_score: raw_score,
            weight: weight,
            weighted_contribution: raw_score * weight
          }
        end
      end

      def compute_component_scores
        {
          price: Scoring::PriceScore.call(flight_sample: flight, analysis_snapshot: snapshot),
          time_comfort: Scoring::TimeComfortScore.call(flight_sample: flight, analysis_snapshot: snapshot),
          trip_fit: Scoring::TripFit.call(flight_sample: flight, search_intent: intent)
        }
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
    end
  end
end
