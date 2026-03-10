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

        intent = Factories::SearchRunFactory.intent_from_record(search_run_record)
        execution = SearchExecution.new(search_run: search_run, intent: intent)

        ActiveRecord::Base.transaction do
          execution.execute

          Mappers::SearchRunMapper.apply(search_run, search_run_record)
          search_run_record.save!

          persist_samples(search_run_record, execution.results)
          persist_analysis_snapshot(search_run_record, execution.analysis_snapshot)

          execution
        end
      rescue => e
        search_run_record.reload

        Mappers::SearchRunMapper.apply(search_run, search_run_record)
        search_run_record.save!(validate: false)

        raise
      end

      def self.load_results(search_run_record)
        ar_snapshot = search_run_record.analysis_snapshot
        return nil unless ar_snapshot

        snapshot = Factories::AnalysisSnapshotFactory.from_record(ar_snapshot)
        intent   = Factories::SearchRunFactory.intent_from_record(search_run_record)

        flight_samples = search_run_record.flight_samples.map do |ar_sample|
          Mappers::FlightSampleMapper.from_hash(ar_sample.attributes.symbolize_keys)
        end.compact

        score_results = flight_samples.map do |sample|
          Scoring::Scorer.new(flight: sample, intent: intent, snapshot: snapshot).call
        end

        explanations = flight_samples.zip(score_results).map do |sample, score_result|
          next unless score_result

          Explanation::Builder.call(
            flight: sample, intent: intent, snapshot: snapshot, score_result: score_result
          )
        end

        ranked_flights = Ranking::Ranker.call(
          flights: flight_samples,
          score_results: score_results,
          explanations: explanations
        )

        insights = Insights::Builder.call(
          ranked_flights: ranked_flights,
          snapshot: snapshot,
          intent: intent
        )

        SearchResults.new(ranked_flights: ranked_flights, insights: insights, snapshot: snapshot)
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
            stops: sample[:stops],
            airlines: sample[:airline_codes],
            luggage_included: sample[:luggage_included],
            departure_datetime: sample[:departure_datetime],
            return_datetime: sample[:return_datetime]
          )
        end
      end

      def self.persist_analysis_snapshot(search_run_record, snapshot)
        return unless snapshot

        AnalysisSnapshot.create!(
          search_run: search_run_record,
          price_p25_cents: snapshot.price_p25_cents,
          price_p50_cents: snapshot.price_p50_cents,
          price_p75_cents: snapshot.price_p75_cents,
          route_median_duration_minutes: snapshot.route_median_duration_minutes.to_i,
          sample_count: snapshot.sample_count,
          confidence_level: snapshot.confidence.to_s,
          volatility: snapshot.volatility.to_s
        )
      end
    end
  end
end
