class AnalysisJob < ApplicationJob
  queue_as :default

  #   Triggered by:
  # 	•	SamplingJob

  # Does:
  # 	•	Compute market stats
  # 	•	Compute volatility
  # 	•	Compute confidence
  # 	•	Persist analysis_snapshot

  # Uses:
  # 	•	Search::Analysis::*
  # 	•	Confidence::*

  # Then:
  # 	•	Set completed_at
  # 	•	Update SearchRun → completed

  # Does NOT:
  # 	•	Rank flights
  # 	•	Produce explanations
  # 	•	Persist scores

  # Those happen at read time.

  #  Domain logic lives on Search::Sampling::* domain classes and Confidence::* domain classes

  def perform(*args)
    # Do something later
  end
end
