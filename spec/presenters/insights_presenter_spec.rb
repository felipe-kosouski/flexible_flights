# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsightsPresenter do
  let(:from_date)    { Date.new(2025, 5, 1) }
  let(:to_date)      { Date.new(2025, 5, 8) }

  let(:date_range_insight) do
    instance_double(
      Search::Insights::DateRangeInsight,
      from_date:      from_date,
      to_date:        to_date,
      average_score:  78.5,
      flight_count:   12,
      confidence_level: :high
    )
  end

  let(:insights) do
    instance_double(
      Search::Insights::SearchInsights,
      best_time_to_travel:     date_range_insight,
      cheapest_comfort_window: date_range_insight,
      wait_or_book:            nil,
      price_rarity:            nil,
      confidence_level:        :high
    )
  end

  describe "InsightsPresenter::DateRangePresenter#search_urls" do
    context "when origin and destination are provided" do
      subject(:presenter) do
        described_class.new(insights, origin: "BCN", destination: "LHR")
      end

      it "returns a FlightSearchUrls struct from best_time_to_travel" do
        expect(presenter.best_time_to_travel.search_urls).to be_a(FlightSearchUrls)
      end

      it "builds a Skyscanner URL with the insight date range" do
        expect(presenter.best_time_to_travel.search_urls.skyscanner_url)
          .to include("BCN/LHR/250501/250508")
      end

      it "builds a Google Flights URL with the insight date range" do
        expect(presenter.best_time_to_travel.search_urls.google_flights_url)
          .to include("f=BCN;t=LHR;d=2025-05-01")
      end

      it "also works for cheapest_comfort_window" do
        expect(presenter.cheapest_comfort_window.search_urls).to be_a(FlightSearchUrls)
      end
    end

    context "when origin and destination are absent" do
      subject(:presenter) { described_class.new(insights) }

      it "returns nil from best_time_to_travel" do
        expect(presenter.best_time_to_travel.search_urls).to be_nil
      end

      it "returns nil from cheapest_comfort_window" do
        expect(presenter.cheapest_comfort_window.search_urls).to be_nil
      end
    end
  end
end
