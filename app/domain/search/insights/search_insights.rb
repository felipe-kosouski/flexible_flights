# frozen_string_literal: true

module Search
  module Insights
    class SearchInsights
      attr_reader :best_time_to_travel, :wait_or_book, :price_rarity,
                  :cheapest_comfort_window, :confidence_level

      def initialize(best_time_to_travel:, wait_or_book:, price_rarity:,
                     cheapest_comfort_window:, confidence_level:)
        @best_time_to_travel = best_time_to_travel
        @wait_or_book = wait_or_book
        @price_rarity = price_rarity
        @cheapest_comfort_window = cheapest_comfort_window
        @confidence_level = confidence_level
        freeze
      end
    end
  end
end
