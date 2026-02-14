# frozen_string_literal: true

module Search
  module Sampling
    class CandidateSelector
      def initialize(date_pairs:, max_candidates:, strategy: :balanced)
        @date_pairs = date_pairs
        @max_candidates = max_candidates
        @strategy = strategy
      end

      def select
        return [] if @date_pairs.empty? || @max_candidates.zero?

        if @date_pairs.size <= @max_candidates
          return ordered_pairs(@date_pairs.uniq)
        end

        select_balanced
      end

      private

      def select_balanced
        pairs_by_departure = @date_pairs.group_by(&:first)
        departure_dates = pairs_by_departure.keys.sort
        unique_departure_dates_count = departure_dates.size

        base_slots = @max_candidates / unique_departure_dates_count
        remainder = @max_candidates % unique_departure_dates_count

        selected = []
        departure_dates.each_with_index do |departure_date, index|
          slots = base_slots + (index < remainder ? 1 : 0)
          pairs_for_departure = pairs_by_departure[departure_date]
            .uniq
            .sort_by(&:last)

          pairs_for_departure.first(slots).each do |pair|
            selected << pair
          end
        end

        selected
      end

      def ordered_pairs(pairs)
        pairs.sort_by { |departure_date, return_date| [ departure_date, return_date ] }
      end
    end
  end
end
