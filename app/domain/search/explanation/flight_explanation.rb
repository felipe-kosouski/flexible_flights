# frozen_string_literal: true

module Search
  module Explanation
    class FlightExplanation
      attr_reader :flight, :score_breakdown, :tradeoffs, :summary

      def initialize(flight:, score_breakdown:, tradeoffs:, summary:)
        @flight = flight
        @score_breakdown = deep_freeze(score_breakdown)
        @tradeoffs = deep_freeze(tradeoffs)
        @summary = deep_freeze(summary)
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
