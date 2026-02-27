# frozen_string_literal: true

module Search
  module Factories
    class SearchRunFactory
      def self.from_record(search_run_record, max_candidates:, passengers:, cabin_class:, provider:)
        intent = search_run_record.search_intent

        SearchRun.new(
          origin: intent.origin_airport,
          destination: intent.destination_airport,
          earliest_departure_date: intent.earliest_departure,
          latest_departure_date: intent.latest_return,
          min_stay_days: intent.min_stay_days,
          max_stay_days: intent.max_stay_days,
          max_candidates: max_candidates,
          passengers: passengers,
          cabin_class: cabin_class,
          provider: provider
        )
      end

      def self.intent_from_record(search_run_record)
        intent = search_run_record.search_intent

        Models::SearchIntent.new(
          min_stay_days: intent.min_stay_days,
          max_stay_days: intent.max_stay_days,
          luggage_requirement: intent.luggage_requirement&.to_sym,
          max_stops: intent.max_stops
        )
      end
    end
  end
end
