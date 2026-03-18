# frozen_string_literal: true

module Search
  module Models
    class SearchIntent
      attr_reader :min_stay_days, :max_stay_days, :luggage_requirement, :max_stops, :currency

      def initialize(
        min_stay_days:,
        max_stay_days:,
        luggage_requirement:,
        max_stops: nil,
        currency: "USD"
      )
        @min_stay_days = min_stay_days
        @max_stay_days = max_stay_days
        @luggage_requirement = luggage_requirement
        @max_stops = max_stops
        @currency = currency
      end
    end
  end
end
