module Search
  module Sampling
    class Runner
      def self.call(**args)
        new(**args).call
      end

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
      end

      def call
        date_pairs = generate_date_pairs
        return [] if date_pairs.empty?

        selected_pairs = select_candidates(date_pairs)
        return [] if selected_pairs.empty?

        sample_flights(selected_pairs)
      end

      private

      def generate_date_pairs
        grid = DateGrid.new(
          earliest_departure_date: @earliest_departure_date,
          latest_departure_date: @latest_departure_date,
          min_stay_days: @min_stay_days,
          max_stay_days: @max_stay_days
        )
        grid.generate
      end

      def select_candidates(date_pairs)
        selector = CandidateSelector.new(
          date_pairs: date_pairs,
          max_candidates: @max_candidates
        )
        selector.select
      end

      def sample_flights(date_pairs)
        sampler = Sampler.new(
          origin: @origin,
          destination: @destination,
          date_pairs: date_pairs,
          passengers: @passengers,
          cabin_class: @cabin_class,
          provider: @provider
        )
        sampler.call
      end
    end
  end
end
