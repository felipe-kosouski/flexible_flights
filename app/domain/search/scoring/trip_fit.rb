# frozen_string_literal: true

module Search
  module Scoring
    class TripFit
      LENGTH_WEIGHT = 0.5
      LUGGAGE_WEIGHT = 0.3
      TIME_WEIGHT = 0.2
      MIDPOINT_TOLERANCE_DAYS = 0.5
      SOFT_RANGE_PERCENTAGE = 0.2
      EDGE_TOLERANCE_DAYS = 3

      def self.call(flight_sample:, search_intent:)
        new(flight_sample, search_intent).score
      end

      def initialize(flight_sample, search_intent)
        @flight = flight_sample
        @intent = search_intent
      end

      SCALE = 100

      def score
        return nil unless hard_constraints_pass?

        raw = (length_fit_score * LENGTH_WEIGHT) +
              (luggage_fit_score * LUGGAGE_WEIGHT) +
              (time_fit_score * TIME_WEIGHT)

        raw * SCALE
      end

      private

      attr_reader :flight, :intent

      def hard_constraints_pass?
        !length_fit_score.nil? && !luggage_fit_score.nil?
      end

      def length_fit_score
        @length_fit_score ||= begin
          stay_length = flight.stay_length_days
          return nil if stay_length <= 0

          length_min = intent.min_stay_days
          length_max = intent.max_stay_days
          return nil if length_min > length_max

          midpoint = (length_min + length_max) / 2.0
          range = length_max - length_min
          margin = range * SOFT_RANGE_PERCENTAGE

          if perfectly_aligned?(stay_length, midpoint)
            1.0
          elsif within_allowed_range?(stay_length, length_min, length_max)
            within_soft_range?(stay_length, midpoint, margin) ? 0.9 : 0.7
          elsif slightly_outside_range?(stay_length, length_min, length_max)
            0.4
          else
            nil
          end
        end
      end

      def within_soft_range?(stay_length, midpoint, margin)
        (stay_length - midpoint).abs <= margin
      end

      def perfectly_aligned?(stay_length, midpoint)
        (stay_length - midpoint).abs <= MIDPOINT_TOLERANCE_DAYS
      end

      def within_allowed_range?(stay_length, min, max)
        stay_length >= min && stay_length <= max
      end

      def slightly_outside_range?(stay_length, min, max)
        below_min_but_close?(stay_length, min) || above_max_but_close?(stay_length, max)
      end

      def below_min_but_close?(stay_length, min)
        stay_length >= (min - EDGE_TOLERANCE_DAYS) && stay_length < min
      end

      def above_max_but_close?(stay_length, max)
        stay_length > max && stay_length <= (max + EDGE_TOLERANCE_DAYS)
      end

      def luggage_fit_score
        case intent.luggage_requirement
        when :required
          flight.luggage_included? ? 1.0 : nil
        when :optional
          flight.luggage_included? ? 1.0 : 0.8
        else
          1.0
        end
      end

      def time_fit_score
        return 1.0 unless flight.has_times?

        if good_times?
          1.0
        elsif very_bad_times?
          0.6
        elsif bad_times?
          0.4
        else
          0.85
        end
      end

      def good_times?
        flight.departure_in_reasonable_window? && flight.arrival_in_reasonable_window?
      end

      def bad_times?
        !flight.departure_in_reasonable_window? && !flight.arrival_in_reasonable_window?
      end

      def very_bad_times?
        flight.red_eye_departure? || flight.very_late_arrival?
      end
    end
  end
end
