class StartSearchRunJob < ApplicationJob
  queue_as :default

  # •	Controller or service explicitly enqueues StartSearchRunJob

  # This job is responsible for starting a search run for a given search intent

  # Triggered when:
  # •	A SearchRun is created

  # Does:
  #   •	Sets started_at
  #   •	Sets status → sampling
  #   •	Enqueues SamplingJob

  # Does NOT:
  #   •	Sample flights
  #   •	Validate business logic
  #   •	Retry endlessly

  # Failure behavior:
  #   •	Mark SearchRun as failed
  #   •	Record error

  def perform(*args)
    # Do something later
  end
end
