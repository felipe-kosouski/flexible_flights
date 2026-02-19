# frozen_string_literal: true

module Search
  module Repositories
    class SearchRunRepository
      def self.execute(search_run_record, provider:, max_candidates:, passengers:, cabin_class:)
        search_run = Factories::SearchRunFactory.from_record(
          search_run_record,
          max_candidates: max_candidates,
          passengers: passengers,
          cabin_class: cabin_class,
          provider: provider
        )

        ActiveRecord::Base.transaction do
          results = search_run.execute

          Mappers::SearchRunMapper.apply(search_run, search_run_record)
          search_run_record.error_message = nil
          search_run_record.save!

          persist_samples(search_run_record, results)

          results
        end
      rescue => e
        # Ensure we are not holding rolled-back state
        search_run_record.reload

        Mappers::SearchRunMapper.apply(search_run, search_run_record)
        search_run_record.error_message = search_run.error&.message || e.message

        # Failure persistence must never be blocked by validations
        search_run_record.save!(validate: false)

        raise
      end

      private

      def self.persist_samples(search_run_record, samples)
        samples.each do |sample|
          FlightSample.create!(
            search_run: search_run_record,
            provider: sample[:raw_provider],
            price_cents: sample[:price_cents],
            currency: sample[:currency],
            air_time_minutes: sample[:air_time_minutes],
            layover_time_minutes: sample[:layover_time_minutes],
            stops: sample[:stops_count],
            airlines: sample[:airline_codes],
            luggage_included: sample[:baggage_included],
            departure_datetime: sample[:departure_date],
            return_datetime: sample[:return_date]
          )
        end
      end
    end
  end
end
