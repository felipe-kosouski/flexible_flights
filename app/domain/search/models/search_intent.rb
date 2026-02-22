# frozen_string_literal: true

module Search
  module Models
    class SearchIntent
      def initialize(
        min_stay_days:,
        max_stay_days:,
        luggage_requirement:
      )
        @min_stay_days       = min_stay_days
        @max_stay_days       = max_stay_days
        @luggage_requirement = luggage_requirement
      end

      attr_reader :min_stay_days, :max_stay_days, :luggage_requirement
    end
  end
end
