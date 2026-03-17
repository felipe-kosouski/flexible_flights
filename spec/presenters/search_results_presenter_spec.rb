# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResultsPresenter do
  include ActiveSupport::Testing::TimeHelpers

  # Build a minimal double for SearchResults and SearchRun.
  # The domain objects are NOT loaded here — we only test the presenter's
  # own methods (stale? and freshness_label). Other presenter behaviour
  # is covered by integration/request specs.

  let(:snapshot) do
    instance_double(
      Search::Models::AnalysisSnapshot,
      confidence: :high,
      sample_count: 10
    )
  end

  let(:results) do
    instance_double(
      Search::SearchResults,
      snapshot: snapshot,
      ranked_flights: [],
      insights: instance_double(Search::Insights::SearchInsights,
                                best_time_to_travel: nil,
                                wait_or_book: nil,
                                price_rarity: nil,
                                cheapest_comfort_window: nil,
                                confidence_level: :high)
    )
  end

  let(:search_intent) do
    instance_double(
      SearchIntent,
      origin_airport: "JFK",
      destination_airport: "LHR",
      id: 1
    )
  end

  def build_presenter(finished_at:)
    run = instance_double(SearchRun,
      search_intent: search_intent,
      completed?: true,
      finished_at: finished_at
    )
    described_class.new(results, run)
  end

  describe "#stale?" do
    it "returns false when finished_at is 6 days ago" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 6.days.ago)
        expect(presenter.stale?).to be false
      end
    end

    it "returns true when finished_at is exactly 7 days ago" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 7.days.ago)
        expect(presenter.stale?).to be true
      end
    end

    it "returns true when finished_at is 8 days ago" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 8.days.ago)
        expect(presenter.stale?).to be true
      end
    end
  end

  describe "#freshness_label" do
    it "returns short form when fresh (< 7 days)" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 2.days.ago)
        expect(presenter.freshness_label).to eq("Analysed 2 days ago")
      end
    end

    it "returns 'consider running again' copy when stale (>= 7 days)" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 12.days.ago)
        expect(presenter.freshness_label).to eq("Analysed 12 days ago · consider running again")
      end
    end

    it "uses singular 'day' when exactly 1 day ago" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 1.day.ago)
        expect(presenter.freshness_label).to eq("Analysed 1 day ago")
      end
    end

    it "returns 'Analysis pending' when finished_at is nil" do
      presenter = build_presenter(finished_at: nil)
      expect(presenter.freshness_label).to eq("Analysis pending")
    end
  end
end
