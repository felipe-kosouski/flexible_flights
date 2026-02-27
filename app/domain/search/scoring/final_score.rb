# frozen_string_literal: true

module Search
  module Scoring
    class FinalScore
      WEIGHTS = {
        price: 0.45,
        time_comfort: 0.35,
        trip_fit: 0.20
      }.freeze

      def initialize(flight:, intent:, snapshot:)
        @flight = flight
        @intent = intent
        @snapshot = snapshot
      end

      def call
        scores = collected_scores
        return nil if scores.empty?

        ScoreResult.new(
          value: weighted_average(scores),
          components: scores
        )
      end

      private

      attr_reader :flight, :intent, :snapshot

      def collected_scores
        {
          price: price_score,
          time_comfort: time_comfort_score,
          trip_fit: trip_fit_score
        }.compact
      end

      def weighted_average(scores)
        total_weight = scores.keys.sum { |k| WEIGHTS[k] }

        scores.sum do |key, score|
          score * (WEIGHTS[key] / total_weight)
        end
      end

      def price_score
        PriceScore.call(
          flight_sample: flight,
          analysis_snapshot: snapshot
        )
      end

      def time_comfort_score
        TimeComfortScore.call(
          flight_sample: flight,
          analysis_snapshot: snapshot
        )
      end

      def trip_fit_score
        TripFit.call(
          flight_sample: flight,
          search_intent: intent
        )
      end
    end
  end
end
