# frozen_string_literal: true

class SearchRunJob < ApplicationJob
  queue_as :default

  # Triggered by: controller after creating a SearchRun record.
  #
  # Wraps the synchronous repository pipeline in an async job so the
  # HTTP request returns immediately while the search executes in the background.
  #
  # The repository owns all state transitions, error handling, and persistence.
  # This job is intentionally thin — it resolves the record, delegates fully,
  # and lets errors propagate so Solid Queue can track failures.
  #
  # Arguments:
  #   search_run_id  - ID of the persisted SearchRun record
  #   provider_name  - String key resolved via Flights::Registry (default: "stub")
  #   max_candidates - Maximum date pairs to sample (default: 20)
  #   passengers     - Number of passengers (default: 1)
  #   cabin_class    - :economy, :business, :first (default: :economy)

  discard_on ActiveRecord::RecordNotFound

  def perform(search_run_id, provider_name: "stub", max_candidates: 20, passengers: 1, cabin_class: :economy)
    provider = Flights::Registry.resolve(provider_name)
    search_run_record = SearchRun.find(search_run_id)

    Search::Repositories::SearchRunRepository.execute(
      search_run_record,
      provider: provider,
      max_candidates: max_candidates,
      passengers: passengers,
      cabin_class: cabin_class
    )
  end
end
