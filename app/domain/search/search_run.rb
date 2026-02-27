# frozen_string_literal: true

module Search
  class SearchRun
    PHASES = %i[
      initialized
      sampling
      analyzing
      scoring
      completed
      failed
    ].freeze

    attr_reader :state, :started_at, :finished_at, :error, :results, :analysis_snapshot, :scored_results

    def initialize(
      origin:,
      destination:,
      earliest_departure_date:,
      latest_departure_date:,
      min_stay_days:,
      max_stay_days:,
      max_candidates:,
      passengers: 1,
      cabin_class: :economy,
      provider:
    )
      @origin = origin
      @destination = destination
      @earliest_departure_date = earliest_departure_date
      @latest_departure_date = latest_departure_date
      @min_stay_days = min_stay_days
      @max_stay_days = max_stay_days
      @max_candidates = max_candidates
      @passengers = passengers
      @cabin_class = cabin_class
      @provider = provider

      @state = :initialized
      @started_at = nil
      @finished_at = nil
      @error = nil
      @results = []
      @analysis_snapshot = nil
      @scored_results = []
    end

    def execute
      ensure_executable!

      @started_at = now
      @state = :sampling

      begin
        @results = Sampling::Runner.call(
          origin: @origin,
          destination: @destination,
          earliest_departure_date: @earliest_departure_date,
          latest_departure_date: @latest_departure_date,
          min_stay_days: @min_stay_days,
          max_stay_days: @max_stay_days,
          max_candidates: @max_candidates,
          passengers: @passengers,
          cabin_class: @cabin_class,
          provider: @provider
        )

        @state = :analyzing
        @analysis_snapshot = Analysis::SnapshotBuilder.build(@results)

        @state = :scoring
        @scored_results = if @analysis_snapshot
          search_intent = build_search_intent
          @results.map do |sample|
            Scoring::Scorer.new(
              flight: sample,
              intent: search_intent,
              snapshot: @analysis_snapshot
            ).call
          end
        else
          []
        end

        @finished_at = now
        @state = :completed
        self
      rescue => e
        @error = e
        @finished_at = now
        @state = :failed
        raise
      end
    end

    private

    def build_search_intent
      Models::SearchIntent.new(
        min_stay_days: @min_stay_days,
        max_stay_days: @max_stay_days,
        luggage_requirement: nil
      )
    end

    def ensure_executable!
      return if @state == :initialized

      raise StandardError, "SearchRun already executed"
    end

    def now
      Time.now
    end
    # TODO: Time source should be injectable
    # def initialize(..., clock: Time)
    #   @clock = clock
    # end
    #
    # def now
    #  @clock.now
    # end
  end
end
