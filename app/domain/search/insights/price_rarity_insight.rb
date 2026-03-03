# frozen_string_literal: true

module Search
  module Insights
    class PriceRarityInsight
      attr_reader :classification, :market_representative_price_cents, :confidence_level

      def initialize(classification:, market_representative_price_cents:, confidence_level:)
        @classification = classification
        @market_representative_price_cents = market_representative_price_cents
        @confidence_level = confidence_level
        freeze
      end
    end
  end
end
