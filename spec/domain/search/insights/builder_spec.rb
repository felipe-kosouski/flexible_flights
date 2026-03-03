# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Insights::Builder do
  # --- helpers ---

  def flight(departure_datetime:, price_cents:)
    Search::Models::FlightSample.new(
      departure_datetime: departure_datetime,
      return_datetime: departure_datetime + (7 * 24 * 3600),
      luggage_included: true,
      price_cents: price_cents,
      stops: 0,
      air_time_minutes: 300,
      layover_time_minutes: 0
    )
  end

  def score(value:, price: nil, time_comfort: nil, trip_fit: nil)
    Search::Scoring::ScoreResult.new(
      value: value,
      components: {
        price: price || value,
        time_comfort: time_comfort || value,
        trip_fit: trip_fit || value
      }
    )
  end

  def ranked(flight:, score_result:, rank:)
    Search::Ranking::RankedFlight.new(
      flight: flight,
      score_result: score_result,
      explanation: nil,
      rank: rank
    )
  end

  def snapshot(confidence: :high, volatility: :low, p25: 10_000, p50: 15_000, p75: 20_000)
    Search::Models::AnalysisSnapshot.new(
      price_p25_cents: p25,
      price_p50_cents: p50,
      price_p75_cents: p75,
      route_median_duration_minutes: 300,
      sample_count: 20,
      volatility: volatility,
      confidence: confidence
    )
  end

  let(:intent) { Search::Models::SearchIntent.new(min_stay_days: 5, max_stay_days: 10, luggage_requirement: :optional) }

  # --- shared ranked_flights for most tests ---

  let(:week_1_flight_a) { flight(departure_datetime: Time.new(2025, 6, 2, 10, 0), price_cents: 9_000) }
  let(:week_1_flight_b) { flight(departure_datetime: Time.new(2025, 6, 4, 10, 0), price_cents: 11_000) }
  let(:week_2_flight_a) { flight(departure_datetime: Time.new(2025, 6, 9, 10, 0), price_cents: 14_000) }
  let(:week_2_flight_b) { flight(departure_datetime: Time.new(2025, 6, 11, 10, 0), price_cents: 16_000) }

  let(:ranked_flights) do
    [
      ranked(flight: week_1_flight_a, score_result: score(value: 90.0, price: 100, time_comfort: 85), rank: 1),
      ranked(flight: week_1_flight_b, score_result: score(value: 85.0, price: 90,  time_comfort: 80), rank: 2),
      ranked(flight: week_2_flight_a, score_result: score(value: 70.0, price: 75,  time_comfort: 72), rank: 3),
      ranked(flight: week_2_flight_b, score_result: score(value: 65.0, price: 60,  time_comfort: 68), rank: 4)
    ]
  end

  let(:default_snapshot) { snapshot }

  describe ".call" do
    context "guard clauses" do
      it "returns nil when snapshot is nil" do
        result = described_class.call(ranked_flights: ranked_flights, snapshot: nil, intent: intent)
        expect(result).to be_nil
      end

      it "returns nil when ranked_flights is nil" do
        result = described_class.call(ranked_flights: nil, snapshot: default_snapshot, intent: intent)
        expect(result).to be_nil
      end
    end

    it "returns a SearchInsights" do
      result = described_class.call(ranked_flights: ranked_flights, snapshot: default_snapshot, intent: intent)
      expect(result).to be_a(Search::Insights::SearchInsights)
    end

    it "is frozen" do
      result = described_class.call(ranked_flights: ranked_flights, snapshot: default_snapshot, intent: intent)
      expect(result).to be_frozen
    end

    it "inherits confidence_level from snapshot" do
      snap = snapshot(confidence: :medium)
      result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent)
      expect(result.confidence_level).to eq(:medium)
    end

    it "produces a result for empty ranked_flights array" do
      result = described_class.call(ranked_flights: [], snapshot: default_snapshot, intent: intent)
      expect(result).to be_a(Search::Insights::SearchInsights)
    end
  end

  describe "wait_or_book" do
    subject(:wait_or_book) do
      described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).wait_or_book
    end

    context "low confidence" do
      let(:snap) { snapshot(confidence: :low) }

      it "is never nil" do
        expect(wait_or_book).not_to be_nil
      end

      it "returns :insufficient_data directive" do
        expect(wait_or_book.directive).to eq(:insufficient_data)
      end

      it "has nil price_band" do
        expect(wait_or_book.price_band).to be_nil
      end
    end

    context "empty ranked_flights" do
      let(:snap) { snapshot }

      subject(:wait_or_book) do
        described_class.call(ranked_flights: [], snapshot: snap, intent: intent).wait_or_book
      end

      it "returns :insufficient_data directive" do
        expect(wait_or_book.directive).to eq(:insufficient_data)
      end

      it "has nil top_flight_median_price_cents" do
        expect(wait_or_book.top_flight_median_price_cents).to be_nil
      end
    end

    context "high volatility overrides cheap price" do
      let(:snap) { snapshot(confidence: :high, volatility: :high, p25: 15_000, p50: 20_000, p75: 25_000) }

      it "returns :wait even though top flights are cheap" do
        # top flight prices are 9_000 and 11_000 — well below p25 of 15_000
        expect(wait_or_book.directive).to eq(:wait)
      end
    end

    context "high confidence + cheap price band" do
      let(:snap) { snapshot(confidence: :high, volatility: :low, p25: 12_000, p50: 15_000, p75: 20_000) }

      it "returns :book_now" do
        # top 3 prices: 9_000, 11_000, 14_000 → median = 11_000 → ≤ p25 12_000 → :cheap
        expect(wait_or_book.directive).to eq(:book_now)
      end

      it "sets price_band to :cheap" do
        expect(wait_or_book.price_band).to eq(:cheap)
      end

      it "includes top_flight_median_price_cents" do
        expect(wait_or_book.top_flight_median_price_cents).to eq(11_000)
      end
    end

    context "medium confidence + cheap price band" do
      let(:snap) { snapshot(confidence: :medium, volatility: :low, p25: 12_000, p50: 15_000, p75: 20_000) }

      it "returns :consider_booking" do
        expect(wait_or_book.directive).to eq(:consider_booking)
      end
    end

    context "medium confidence + below_median price band" do
      let(:snap) { snapshot(confidence: :medium, volatility: :low, p25: 8_000, p50: 15_000, p75: 20_000) }

      it "returns :consider_booking" do
        # top 3 prices: 9_000, 11_000, 14_000 → median = 11_000 → p25=8_000 < 11_000 ≤ p50=15_000 → :below_median
        expect(wait_or_book.directive).to eq(:consider_booking)
      end
    end

    context "high confidence + below_median price band" do
      let(:snap) { snapshot(confidence: :high, volatility: :low, p25: 8_000, p50: 15_000, p75: 20_000) }

      it "returns :consider_booking" do
        expect(wait_or_book.directive).to eq(:consider_booking)
      end
    end

    context "high confidence + above_median price band" do
      let(:snap) { snapshot(confidence: :high, volatility: :low, p25: 8_000, p50: 10_000, p75: 20_000) }

      it "returns :wait" do
        # top 3 prices: 9_000, 11_000, 14_000 → median = 11_000 → p50=10_000 < 11_000 ≤ p75=20_000 → :above_median
        expect(wait_or_book.directive).to eq(:wait)
      end
    end

    context "high confidence + expensive price band" do
      let(:snap) { snapshot(confidence: :high, volatility: :low, p25: 5_000, p50: 8_000, p75: 10_000) }

      it "returns :wait" do
        # top 3 prices: 9_000, 11_000, 14_000 → median = 11_000 → > p75=10_000 → :expensive
        expect(wait_or_book.directive).to eq(:wait)
      end

      it "sets price_band to :expensive" do
        expect(wait_or_book.price_band).to eq(:expensive)
      end
    end

    context "uses top 3 flights for price signal" do
      let(:snap) { snapshot(confidence: :high, volatility: :low, p25: 12_000, p50: 15_000, p75: 20_000) }

      it "uses median of top 3 ranked flights, not all flights" do
        # top 3 prices: 9_000, 11_000, 14_000 → odd count → middle = 11_000
        expect(wait_or_book.top_flight_median_price_cents).to eq(11_000)
      end
    end
  end

  describe "best_time_to_travel" do
    subject(:best_time) do
      described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).best_time_to_travel
    end

    context "low confidence" do
      let(:snap) { snapshot(confidence: :low) }

      it "returns nil" do
        expect(best_time).to be_nil
      end
    end

    context "empty ranked_flights" do
      let(:snap) { snapshot }

      subject(:best_time) do
        described_class.call(ranked_flights: [], snapshot: snap, intent: intent).best_time_to_travel
      end

      it "returns nil" do
        expect(best_time).to be_nil
      end
    end

    context "no week bucket has >= 2 flights" do
      let(:snap) { snapshot }
      let(:single_flights) do
        [
          ranked(flight: week_1_flight_a, score_result: score(value: 90.0), rank: 1),
          ranked(flight: week_2_flight_a, score_result: score(value: 85.0), rank: 2)
        ]
      end

      subject(:best_time) do
        described_class.call(ranked_flights: single_flights, snapshot: snap, intent: intent).best_time_to_travel
      end

      it "returns nil" do
        expect(best_time).to be_nil
      end
    end

    context "with multiple week buckets" do
      let(:snap) { snapshot }

      it "returns a DateRangeInsight" do
        expect(best_time).to be_a(Search::Insights::DateRangeInsight)
      end

      it "selects the week with the highest average score" do
        # Week 1 avg = (90 + 85) / 2 = 87.5; Week 2 avg = (70 + 65) / 2 = 67.5
        expect(best_time.from_date).to eq(Date.new(2025, 6, 2))
        expect(best_time.to_date).to eq(Date.new(2025, 6, 4))
      end

      it "reports the correct flight_count" do
        expect(best_time.flight_count).to eq(2)
      end

      it "reports the correct average_score" do
        expect(best_time.average_score).to eq(87.5)
      end

      it "inherits confidence_level from snapshot" do
        expect(best_time.confidence_level).to eq(:high)
      end

      it "is frozen" do
        expect(best_time).to be_frozen
      end
    end

    context "tie-breaking by earlier week" do
      let(:snap) { snapshot }
      let(:tied_flights) do
        flight_w22a = flight(departure_datetime: Time.new(2025, 6, 2, 10, 0), price_cents: 10_000)
        flight_w22b = flight(departure_datetime: Time.new(2025, 6, 4, 10, 0), price_cents: 10_000)
        flight_w23a = flight(departure_datetime: Time.new(2025, 6, 9, 10, 0), price_cents: 10_000)
        flight_w23b = flight(departure_datetime: Time.new(2025, 6, 11, 10, 0), price_cents: 10_000)
        [
          ranked(flight: flight_w22a, score_result: score(value: 80.0), rank: 1),
          ranked(flight: flight_w22b, score_result: score(value: 80.0), rank: 2),
          ranked(flight: flight_w23a, score_result: score(value: 80.0), rank: 3),
          ranked(flight: flight_w23b, score_result: score(value: 80.0), rank: 4)
        ]
      end

      subject(:best_time) do
        described_class.call(ranked_flights: tied_flights, snapshot: snap, intent: intent).best_time_to_travel
      end

      it "selects the earlier week when scores are equal" do
        expect(best_time.from_date).to eq(Date.new(2025, 6, 2))
      end
    end
  end

  describe "price_rarity" do
    subject(:price_rarity) do
      described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
    end

    context "low confidence" do
      let(:snap) { snapshot(confidence: :low) }

      it "returns nil" do
        expect(price_rarity).to be_nil
      end
    end

    context "empty ranked_flights" do
      let(:snap) { snapshot }

      subject(:price_rarity) do
        described_class.call(ranked_flights: [], snapshot: snap, intent: intent).price_rarity
      end

      it "returns nil" do
        expect(price_rarity).to be_nil
      end
    end

    context "price distribution not present" do
      let(:snap) do
        Search::Models::AnalysisSnapshot.new(
          price_p25_cents: nil,
          price_p50_cents: nil,
          price_p75_cents: nil,
          route_median_duration_minutes: 300,
          sample_count: 5,
          volatility: :low,
          confidence: :medium
        )
      end

      it "returns nil" do
        expect(price_rarity).to be_nil
      end
    end

    context "with price distribution" do
      # All flight prices: 9_000, 11_000, 14_000, 16_000 → sorted median = (11_000 + 14_000) / 2 = 12_500

      it "returns a PriceRarityInsight" do
        snap = snapshot(p25: 10_000, p50: 15_000, p75: 20_000)
        result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
        expect(result).to be_a(Search::Insights::PriceRarityInsight)
      end

      it "classifies as :rare_cheap when median <= p25" do
        snap = snapshot(p25: 13_000, p50: 18_000, p75: 22_000)
        result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
        expect(result.classification).to eq(:rare_cheap)
      end

      it "classifies as :below_median when median is between p25 and p50" do
        snap = snapshot(p25: 10_000, p50: 15_000, p75: 20_000)
        result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
        # median price = 12_500 → p25=10_000 < 12_500 ≤ p50=15_000
        expect(result.classification).to eq(:below_median)
      end

      it "classifies as :above_median when median is between p50 and p75" do
        snap = snapshot(p25: 8_000, p50: 11_000, p75: 20_000)
        result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
        # median price = 12_500 → p50=11_000 < 12_500 ≤ p75=20_000
        expect(result.classification).to eq(:above_median)
      end

      it "classifies as :expensive when median > p75" do
        snap = snapshot(p25: 5_000, p50: 8_000, p75: 10_000)
        result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
        # median price = 12_500 → > p75=10_000
        expect(result.classification).to eq(:expensive)
      end

      it "reports the market_representative_price_cents" do
        snap = snapshot(p25: 10_000, p50: 15_000, p75: 20_000)
        result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
        expect(result.market_representative_price_cents).to eq(12_500)
      end

      it "is frozen" do
        snap = snapshot(p25: 10_000, p50: 15_000, p75: 20_000)
        result = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).price_rarity
        expect(result).to be_frozen
      end
    end
  end

  describe "cheapest_comfort_window" do
    subject(:comfort_window) do
      described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent).cheapest_comfort_window
    end

    context "low confidence" do
      let(:snap) { snapshot(confidence: :low) }

      it "returns nil" do
        expect(comfort_window).to be_nil
      end
    end

    context "fewer than 2 balanced flights" do
      let(:snap) { snapshot }

      let(:ranked_flights) do
        # Only 1 flight meets both thresholds (price: 100, time_comfort: 85 → both ≥ 70)
        # The second has time_comfort: 65 — below threshold
        [
          ranked(flight: week_1_flight_a, score_result: score(value: 90.0, price: 100, time_comfort: 85), rank: 1),
          ranked(flight: week_1_flight_b, score_result: score(value: 75.0, price: 80,  time_comfort: 65), rank: 2)
        ]
      end

      it "returns nil" do
        expect(comfort_window).to be_nil
      end
    end

    context "with 2+ balanced flights" do
      let(:snap) { snapshot }

      # ranked_flights from let above has:
      # rank 1: price=100, time_comfort=85 → both ≥ 70 ✓
      # rank 2: price=90,  time_comfort=80 → both ≥ 70 ✓
      # rank 3: price=75,  time_comfort=72 → both ≥ 70 ✓
      # rank 4: price=60,  time_comfort=68 → time_comfort < 70 ✗

      it "returns a DateRangeInsight" do
        expect(comfort_window).to be_a(Search::Insights::DateRangeInsight)
      end

      it "includes the correct flight_count" do
        expect(comfort_window.flight_count).to eq(3)
      end

      it "spans from the earliest to latest departure of balanced flights" do
        expect(comfort_window.from_date).to eq(Date.new(2025, 6, 2))
        expect(comfort_window.to_date).to eq(Date.new(2025, 6, 9))
      end

      it "is frozen" do
        expect(comfort_window).to be_frozen
      end
    end

    context "requires both price AND time_comfort to be >= threshold" do
      let(:snap) { snapshot }

      let(:ranked_flights) do
        good_price_bad_comfort = flight(departure_datetime: Time.new(2025, 6, 2, 10, 0), price_cents: 9_000)
        bad_price_good_comfort = flight(departure_datetime: Time.new(2025, 6, 9, 10, 0), price_cents: 9_000)
        [
          ranked(flight: good_price_bad_comfort, score_result: score(value: 75.0, price: 90, time_comfort: 60), rank: 1),
          ranked(flight: bad_price_good_comfort, score_result: score(value: 70.0, price: 55, time_comfort: 90), rank: 2)
        ]
      end

      it "returns nil when no flight has both dimensions >= threshold" do
        expect(comfort_window).to be_nil
      end
    end
  end

  describe "determinism" do
    it "returns identical results for identical inputs" do
      snap = snapshot
      result_a = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent)
      result_b = described_class.call(ranked_flights: ranked_flights, snapshot: snap, intent: intent)

      expect(result_a.confidence_level).to eq(result_b.confidence_level)
      expect(result_a.wait_or_book.directive).to eq(result_b.wait_or_book.directive)
      expect(result_a.best_time_to_travel&.from_date).to eq(result_b.best_time_to_travel&.from_date)
      expect(result_a.price_rarity&.classification).to eq(result_b.price_rarity&.classification)
    end
  end
end
