# frozen_string_literal: true

module Search
  module Scoring
    class Scorer
      def initialize(flight:, intent:, snapshot:)
        @flight = flight
        @intent = intent
        @snapshot = snapshot
      end

      def call
        FinalScore.new(
          flight: @flight,
          intent: @intent,
          snapshot: @snapshot
        ).call
      end
    end
  end
end
