# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Sampling::CandidateSelector do
  describe "#select" do
    it "returns all pairs when size <= max_candidates" do
      date_pairs = [
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 7) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 8) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 10)

      result = selector.select

      expect(result.size).to eq(3)
      expect(result).to contain_exactly(*date_pairs)
    end

    it "returns pairs ordered by departure_date ASC, return_date ASC" do
      date_pairs = [
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 9) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 7) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 5)

      result = selector.select

      expect(result).to eq(result.sort_by { |dep, ret| [ dep, ret ] })
      expect(result.first).to eq([ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ])
    end

    it "selects evenly across departure dates when exceeding max_candidates" do
      # 3 departure dates, 4 pairs each = 12 total; max 6 candidates
      # base_slots = 6/3 = 2, remainder = 0 → 2 slots per departure
      date_pairs = [
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 7) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 8) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 9) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 7) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 8) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 9) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 10) ],
        [ Date.new(2025, 3, 3), Date.new(2025, 3, 8) ],
        [ Date.new(2025, 3, 3), Date.new(2025, 3, 9) ],
        [ Date.new(2025, 3, 3), Date.new(2025, 3, 10) ],
        [ Date.new(2025, 3, 3), Date.new(2025, 3, 11) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 6)

      result = selector.select

      expect(result.size).to eq(6)
      expect(result.map(&:first).tally.values).to all(eq(2))
      expect(result.map(&:first).uniq.sort).to eq([ Date.new(2025, 3, 1), Date.new(2025, 3, 2), Date.new(2025, 3, 3) ])
    end

    it "selects earliest return dates first within each departure date" do
      date_pairs = [
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 9) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 7) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 8) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 2)

      result = selector.select

      expect(result).to eq([
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 7) ]
      ])
    end

    it "returns empty array when date_pairs is empty" do
      selector = described_class.new(date_pairs: [], max_candidates: 10)

      result = selector.select

      expect(result).to eq([])
    end

    it "returns empty array when max_candidates is 0" do
      date_pairs = [
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 0)

      result = selector.select

      expect(result).to eq([])
    end

    it "gives zero slots to some departure dates when D > max_candidates" do
      # 4 departure dates, max 2 candidates → first 2 dates get 1 slot each, rest get 0
      date_pairs = [
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 7) ],
        [ Date.new(2025, 3, 3), Date.new(2025, 3, 8) ],
        [ Date.new(2025, 3, 4), Date.new(2025, 3, 9) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 2)

      result = selector.select

      expect(result.size).to eq(2)
      expect(result.map(&:first)).to eq([ Date.new(2025, 3, 1), Date.new(2025, 3, 2) ])
    end

    it "fills single departure date using earliest returns" do
      date_pairs = [
        [ Date.new(2025, 4, 15), Date.new(2025, 4, 22) ],
        [ Date.new(2025, 4, 15), Date.new(2025, 4, 20) ],
        [ Date.new(2025, 4, 15), Date.new(2025, 4, 21) ],
        [ Date.new(2025, 4, 15), Date.new(2025, 4, 23) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 2)

      result = selector.select

      expect(result.size).to eq(2)
      expect(result.map(&:first).uniq).to eq([ Date.new(2025, 4, 15) ])
      expect(result.map(&:last)).to eq([ Date.new(2025, 4, 20), Date.new(2025, 4, 21) ])
    end

    it "is deterministic" do
      date_pairs = [
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 7) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 8) ],
        [ Date.new(2025, 3, 2), Date.new(2025, 3, 9) ],
        [ Date.new(2025, 3, 3), Date.new(2025, 3, 10) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 3)

      first_run = selector.select
      second_run = selector.select

      expect(first_run).to eq(second_run)
    end

    it "returns no duplicates" do
      date_pairs = [
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 6) ],
        [ Date.new(2025, 3, 1), Date.new(2025, 3, 7) ]
      ]
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 5)

      result = selector.select

      expect(result.uniq).to eq(result)
      expect(result.size).to eq(2)
    end

    it "allocates remainder slots to earliest departure dates" do
      # 3 departure dates, 7 max_candidates → base=2, remainder=1
      # First departure gets 3, others get 2 each
      date_pairs = (1..3).flat_map do |d|
        (6..9).map { |r| [ Date.new(2025, 3, d), Date.new(2025, 3, r) ] }
      end
      selector = described_class.new(date_pairs: date_pairs, max_candidates: 7)

      result = selector.select

      expect(result.size).to eq(7)
      by_departure = result.group_by(&:first)
      expect(by_departure[Date.new(2025, 3, 1)].size).to eq(3)
      expect(by_departure[Date.new(2025, 3, 2)].size).to eq(2)
      expect(by_departure[Date.new(2025, 3, 3)].size).to eq(2)
    end
  end
end
