# frozen_string_literal: true

module Search
  module Insights
    class DateRangeInsight
      attr_reader :from_date, :to_date, :average_score, :flight_count, :confidence_level

      def initialize(from_date:, to_date:, average_score:, flight_count:, confidence_level:)
        @from_date = from_date
        @to_date = to_date
        @average_score = average_score
        @flight_count = flight_count
        @confidence_level = confidence_level
        freeze
      end
    end
  end
end
