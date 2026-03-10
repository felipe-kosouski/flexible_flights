# frozen_string_literal: true

module Search
  # Frozen value object returned by SearchRunRepository.load_results.
  # Carries computed results derived from persisted raw data.
  SearchResults = Struct.new(:ranked_flights, :insights, :snapshot, keyword_init: true) do
    def initialize(...)
      super
      freeze
    end
  end
end
