# frozen_string_literal: true

module Search
  module Explanation
    class FlightExplanation
      attr_reader :flight, :final_score, :score_breakdown, :tradeoffs, :summary,
                  :baselines, :metadata

      def initialize(flight:, final_score:, score_breakdown:, tradeoffs:, summary:, baselines:, metadata:)
        @flight = flight
        @final_score = final_score
        @score_breakdown = deep_freeze(score_breakdown)
        @tradeoffs = deep_freeze(tradeoffs)
        @summary = deep_freeze(summary)
        @baselines = deep_freeze(baselines)
        @metadata = deep_freeze(metadata)
        freeze
      end

      private

      def deep_freeze(collection)
        case collection
        when Array
          collection.each { |item| deep_freeze(item) }.freeze
        when Hash
          collection.each_value { |v| deep_freeze(v) }.freeze
        else
          collection.freeze rescue collection
        end
      end
    end
  end
end
