# frozen_string_literal: true

module Search
  class SearchExecution
    PHASES = %i[initialized sampling mapping analyzing scoring explaining ranking insights completed failed].freeze

    attr_reader :state, :search_run, :flight_samples, :analysis_snapshot,
                :scored_results, :explanations, :ranked_results, :insights, :error

    def initialize(search_run:, intent:)
      @search_run = search_run
      @intent = intent
      @state = :initialized
      @flight_samples = []
      @analysis_snapshot = nil
      @scored_results = []
      @explanations = []
      @ranked_results = []
      @insights = nil
      @error = nil
    end

    def execute
      @state = :sampling
      @search_run.execute

      @state = :mapping
      @flight_samples = Mappers::FlightSampleMapper.map_all(@search_run.results)

      @state = :analyzing
      @analysis_snapshot = Analysis::SnapshotBuilder.build(@flight_samples)

      @state = :scoring
      @scored_results = score_flights

      @state = :explaining
      @explanations = build_explanations

      @state = :ranking
      @ranked_results = Ranking::Ranker.call(
        flights: @flight_samples,
        score_results: @scored_results,
        explanations: @explanations
      )

      @state = :insights
      @insights = build_insights

      @state = :completed
      self
    rescue => e
      @error = e
      @state = :failed
      raise
    end

    def results
      @search_run.results
    end

    private

    def score_flights
      return [] unless @analysis_snapshot

      @flight_samples.map do |sample|
        Scoring::Scorer.new(
          flight: sample,
          intent: @intent,
          snapshot: @analysis_snapshot
        ).call
      end
    end

    def build_explanations
      return [] unless @analysis_snapshot

      @flight_samples.zip(@scored_results).map do |sample, score_result|
        next unless score_result

        Explanation::Builder.call(
          flight: sample,
          intent: @intent,
          snapshot: @analysis_snapshot,
          score_result: score_result
        )
      end
    end

    def build_insights
      return nil unless @analysis_snapshot

      Insights::Builder.call(
        ranked_flights: @ranked_results,
        snapshot: @analysis_snapshot,
        intent: @intent
      )
    end
  end
end
