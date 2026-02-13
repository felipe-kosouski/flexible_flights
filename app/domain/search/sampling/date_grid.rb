# frozen_string_literal: true

module Search
  module Sampling
    class DateGrid
      def initialize(earliest_departure_date:, latest_departure_date:, min_stay_days:, max_stay_days:)
        @earliest_departure_date = earliest_departure_date
        @latest_departure_date = latest_departure_date
        @min_stay_days = min_stay_days
        @max_stay_days = max_stay_days
      end

      def generate
        pairs = []

        departure_dates.each do |departure_date|
          stay_range.each do |stay_days|
            return_date = departure_date + stay_days
            next unless valid_pair?(departure_date, return_date)

            pairs << [ departure_date, return_date ]
          end
        end

        pairs
      end

      private

      def departure_dates
        @earliest_departure_date..@latest_departure_date
      end

      def stay_range
        @min_stay_days..@max_stay_days
      end

      def valid_pair?(departure, return_date)
        return_date > departure
      end
    end
  end
end
