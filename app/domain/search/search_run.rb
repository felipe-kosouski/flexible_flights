# frozen_string_literal: true

module Search
  class SearchRun
    attr_reader :state, :started_at, :finished_at, :error, :results

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

        @finished_at = now
        @state = :completed
        @results
      rescue => e
        @error = e
        @finished_at = now
        @state = :failed
        raise
      end
    end

    private

    def ensure_executable!
      return if @state == :initialized

      raise StandardError, "SearchRun already executed"
    end

    def now
      Time.now
    end
  end
end
