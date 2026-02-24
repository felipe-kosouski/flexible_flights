# frozen_string_literal: true

module Search
  module Scoring
    class TimeComfortScore
      STOPS_WEIGHT = 0.6
      DURATION_WEIGHT = 0.4
      LAYOVER_PENALTY = 1.3

      STOPS_SCORES = { 0 => 100, 1 => 80, 2 => 50 }.freeze
      DEFAULT_STOPS_SCORE = 20

      def self.call(flight_sample:, analysis_snapshot:)
        new(flight_sample, analysis_snapshot).score
      end

      def initialize(flight_sample, analysis_snapshot)
        @flight   = flight_sample
        @snapshot = analysis_snapshot
      end

      def score
        return nil unless inputs_valid?

        (stops_score * STOPS_WEIGHT) + (duration_score * DURATION_WEIGHT)
      end

      private

      attr_reader :flight, :snapshot

      def inputs_valid?
        !flight.stops.nil? &&
          !flight.air_time_minutes.nil? &&
          !flight.layover_time_minutes.nil? &&
          !snapshot.route_median_duration_minutes.nil?
      end

      def stops_score
        STOPS_SCORES.fetch(flight.stops, DEFAULT_STOPS_SCORE)
      end

      def duration_score
        case relative_duration
        when 0.0..0.9
          100
        when 0.9..1.1
          80
        when 1.1..1.3
          50
        else
          20
        end
      end

      def effective_duration
        flight.air_time_minutes + (flight.layover_time_minutes * LAYOVER_PENALTY)
      end

      def relative_duration
        effective_duration / snapshot.route_median_duration_minutes
      end
    end
  end
end
