# frozen_string_literal: true

module Search
  module Scoring
    class ScoreResult
      attr_reader :value, :components

      def initialize(value:, components:)
        @value = value
        @components = components.freeze
        freeze
      end
    end
  end
end
