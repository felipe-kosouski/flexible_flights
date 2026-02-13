class SamplingJob < ApplicationJob
  queue_as :default

  # This job is responsible for sampling flights for a given search run
  #   Triggered by:
  # 	•	StartSearchRunJob

  # Does:
  # 	•	Build date combinations (domain logic)
  # 	•	Call flight providers
  # 	•	Persist flight_samples

  # Uses:
  # 	•	Search::Sampling::* domain classes

  # Rules:
  # 	•	No scoring
  # 	•	No analysis
  # 	•	No assumptions about “best” flights

  # Exit conditions:
  # 	•	Minimum viable sample size reached
  # 	•	OR provider limits reached

  # Then:
  # 	•	Update SearchRun → analyzing
  # 	•	Enqueue AnalysisJob

  # Failure behavior:
  # 	•	Mark SearchRun as failed

  # Domain logic lives on Search::Sampling::* domain classes
  def perform(*args)
    # Do something later
  end
end
