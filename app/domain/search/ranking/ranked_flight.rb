# frozen_string_literal: true

module Search
  module Ranking
    class RankedFlight
      attr_reader :flight, :score_result, :explanation, :rank

      def initialize(flight:, score_result:, explanation:, rank:)
        @flight = flight
        @score_result = score_result
        @explanation = explanation
        @rank = rank
        freeze
      end
    end
  end
end
