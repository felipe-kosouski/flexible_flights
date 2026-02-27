# frozen_string_literal: true

module Search
  module Ranking
    class Ranker
      def self.call(flights:, score_results:, explanations:)
        new(flights: flights, score_results: score_results, explanations: explanations).call
      end

      def initialize(flights:, score_results:, explanations:)
        @flights = flights
        @score_results = score_results
        @explanations = explanations
      end

      def call
        triples = build_triples
        sorted = sort_triples(triples)
        assign_ranks(sorted)
      end

      private

      attr_reader :flights, :score_results, :explanations

      def build_triples
        flights.zip(score_results, explanations).select { |_flight, score_result, _explanation| score_result }
      end

      def sort_triples(triples)
        triples.sort_by do |flight, score_result, _explanation|
          [
            -score_result.value,
            flight.price_cents || Float::INFINITY,
            flight.stops || Float::INFINITY
          ]
        end
      end

      def assign_ranks(sorted_triples)
        sorted_triples.each_with_index.map do |(flight, score_result, explanation), index|
          RankedFlight.new(
            flight: flight,
            score_result: score_result,
            explanation: explanation,
            rank: index + 1
          )
        end
      end
    end
  end
end
