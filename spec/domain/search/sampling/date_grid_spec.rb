# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Sampling::DateGrid do
  describe "#generate" do
    it "returns all valid (departure_date, return_date) pairs" do
      grid = described_class.new(
        earliest_departure_date: Date.new(2025, 3, 1),
        latest_departure_date: Date.new(2025, 3, 3),
        min_stay_days: 5,
        max_stay_days: 7
      )

      pairs = grid.generate

      expect(pairs.size).to eq(9)
      expect(pairs.first).to eq([ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ])
      expect(pairs.last).to eq([ Date.new(2025, 3, 3), Date.new(2025, 3, 10) ])
    end

    it "returns pairs ordered by departure_date ASC, return_date ASC" do
      grid = described_class.new(
        earliest_departure_date: Date.new(2025, 3, 10),
        latest_departure_date: Date.new(2025, 3, 12),
        min_stay_days: 1,
        max_stay_days: 2
      )

      pairs = grid.generate

      expect(pairs).to eq(pairs.sort_by { |dep, ret| [ dep, ret ] })
    end

    it "returns empty array when no valid pairs exist" do
      grid = described_class.new(
        earliest_departure_date: Date.new(2025, 3, 5),
        latest_departure_date: Date.new(2025, 3, 1),
        min_stay_days: 1,
        max_stay_days: 3
      )

      pairs = grid.generate

      expect(pairs).to eq([])
    end

    it "excludes pairs where return_date equals departure_date" do
      grid = described_class.new(
        earliest_departure_date: Date.new(2025, 3, 1),
        latest_departure_date: Date.new(2025, 3, 1),
        min_stay_days: 0,
        max_stay_days: 2
      )

      pairs = grid.generate

      expect(pairs).not_to include([ Date.new(2025, 3, 1), Date.new(2025, 3, 1) ])
      expect(pairs).to include([ Date.new(2025, 3, 1), Date.new(2025, 3, 2) ])
    end

    it "is deterministic" do
      grid = described_class.new(
        earliest_departure_date: Date.new(2025, 3, 1),
        latest_departure_date: Date.new(2025, 3, 5),
        min_stay_days: 3,
        max_stay_days: 5
      )

      first_run = grid.generate
      second_run = grid.generate

      expect(first_run).to eq(second_run)
    end

    it "handles single departure date with multiple stay lengths" do
      grid = described_class.new(
        earliest_departure_date: Date.new(2025, 4, 15),
        latest_departure_date: Date.new(2025, 4, 15),
        min_stay_days: 2,
        max_stay_days: 4
      )

      pairs = grid.generate

      expect(pairs.size).to eq(3)
      expect(pairs.map(&:first).uniq).to eq([ Date.new(2025, 4, 15) ])
      expect(pairs.map(&:last)).to contain_exactly(
        Date.new(2025, 4, 17),
        Date.new(2025, 4, 18),
        Date.new(2025, 4, 19)
      )
    end

    it "handles single day stay range" do
      grid = described_class.new(
        earliest_departure_date: Date.new(2025, 5, 1),
        latest_departure_date: Date.new(2025, 5, 3),
        min_stay_days: 7,
        max_stay_days: 7
      )

      pairs = grid.generate

      expect(pairs.size).to eq(3)
      pairs.each do |departure, return_date|
        expect(return_date - departure).to eq(7)
      end
    end
  end
end
