# frozen_string_literal: true

#
# End-to-end manual test for the Insights domain.
#
# Run from the Rails console:
#   load Rails.root.join("script/insights_console_test.rb")
#
# The script builds domain objects directly (no DB, no HTTP) and calls
# Search::Insights::Builder for four distinct scenarios, printing a human-
# readable summary of every insight attribute after each run.

puts "\n" + ("=" * 70)
puts "  Insights Domain — End-to-End Console Test"
puts "=" * 70

# ─── Shared helpers ──────────────────────────────────────────────────────────

def flight(departure_date:, price_cents:, stops: 0, air_time_minutes: 360)
  Search::Models::FlightSample.new(
    departure_datetime: Time.zone.parse("#{departure_date} 08:30"),
    return_datetime:    Time.zone.parse("#{departure_date} 08:30") + 7.days + 19.hours,
    luggage_included:   true,
    price_cents:        price_cents,
    stops:              stops,
    air_time_minutes:   air_time_minutes,
    layover_time_minutes: stops > 0 ? 90 : 0
  )
end

def score(value:, price:, time_comfort:, trip_fit:)
  Search::Scoring::ScoreResult.new(
    value:      value,
    components: { price: price, time_comfort: time_comfort, trip_fit: trip_fit }
  )
end

def ranked(flight:, score_result:, rank:)
  Search::Ranking::RankedFlight.new(
    flight:       flight,
    score_result: score_result,
    explanation:  nil,
    rank:         rank
  )
end

def snapshot(confidence:, volatility:, p25: 20_000, p50: 30_000, p75: 40_000)
  Search::Models::AnalysisSnapshot.new(
    price_p25_cents:             p25,
    price_p50_cents:             p50,
    price_p75_cents:             p75,
    route_median_duration_minutes: 360,
    sample_count:                6,
    volatility:                  volatility,
    confidence:                  confidence
  )
end

def print_insights(label, insights)
  puts "\n#{label}"
  puts "-" * 60

  if insights.nil?
    puts "  Builder returned nil (snapshot was nil)"
    return
  end

  puts "  confidence_level:         #{insights.confidence_level}"

  # wait_or_book
  wob = insights.wait_or_book
  puts "\n  wait_or_book:"
  puts "    directive:                #{wob.directive}"
  puts "    price_band:               #{wob.price_band.inspect}"
  puts "    top_flight_median_cents:  #{wob.top_flight_median_price_cents.inspect}"

  # best_time_to_travel
  btt = insights.best_time_to_travel
  if btt
    puts "\n  best_time_to_travel:"
    puts "    from_date:     #{btt.from_date}"
    puts "    to_date:       #{btt.to_date}"
    puts "    average_score: #{btt.average_score.round(1)}"
    puts "    flight_count:  #{btt.flight_count}"
  else
    puts "\n  best_time_to_travel:      nil"
  end

  # cheapest_comfort_window
  ccw = insights.cheapest_comfort_window
  if ccw
    puts "\n  cheapest_comfort_window:"
    puts "    from_date:     #{ccw.from_date}"
    puts "    to_date:       #{ccw.to_date}"
    puts "    average_score: #{ccw.average_score.round(1)}"
    puts "    flight_count:  #{ccw.flight_count}"
  else
    puts "\n  cheapest_comfort_window:  nil"
  end

  # price_rarity
  pr = insights.price_rarity
  if pr
    puts "\n  price_rarity:"
    puts "    classification:           #{pr.classification}"
    puts "    market_price_cents:       #{pr.market_representative_price_cents}"
  else
    puts "\n  price_rarity:             nil"
  end
end

# ─── Shared flight data ───────────────────────────────────────────────────────
#
# Week A  (ISO week of 2026-03-09): 3 cheap flights, high scores
# Week B  (ISO week of 2026-03-16): 3 mid-range flights, lower scores
#
# Price thresholds (snapshot): p25=200 USD, p50=300 USD, p75=400 USD

flights_week_a = [
  flight(departure_date: "2026-03-09", price_cents: 16_000),  # 160 USD — below p25
  flight(departure_date: "2026-03-11", price_cents: 17_000),  # 170 USD
  flight(departure_date: "2026-03-13", price_cents: 18_000)  # 180 USD
]
scores_week_a = [
  score(value: 90, price: 88, time_comfort: 86, trip_fit: 80),
  score(value: 88, price: 85, time_comfort: 84, trip_fit: 82),
  score(value: 85, price: 82, time_comfort: 83, trip_fit: 75)
]

flights_week_b = [
  flight(departure_date: "2026-03-16", price_cents: 28_000),  # 280 USD — between p25/p50
  flight(departure_date: "2026-03-18", price_cents: 29_000),
  flight(departure_date: "2026-03-20", price_cents: 30_000)
]
scores_week_b = [
  score(value: 75, price: 72, time_comfort: 76, trip_fit: 70),
  score(value: 72, price: 70, time_comfort: 74, trip_fit: 68),
  score(value: 70, price: 68, time_comfort: 73, trip_fit: 65)  # price 68 < 70 → not balanced
]

all_ranked = [
  ranked(flight: flights_week_a[0], score_result: scores_week_a[0], rank: 1),
  ranked(flight: flights_week_a[1], score_result: scores_week_a[1], rank: 2),
  ranked(flight: flights_week_a[2], score_result: scores_week_a[2], rank: 3),
  ranked(flight: flights_week_b[0], score_result: scores_week_b[0], rank: 4),
  ranked(flight: flights_week_b[1], score_result: scores_week_b[1], rank: 5),
  ranked(flight: flights_week_b[2], score_result: scores_week_b[2], rank: 6)
]

# ─── Scenario A: High confidence, low volatility, cheap top flights ───────────
#
# Expected:
#   wait_or_book.directive        → :book_now
#     (top-3 median = 17 000 ≤ p25, confidence :high, volatility :low)
#   best_time_to_travel           → week of 2026-03-09 (avg score 87.7)
#   cheapest_comfort_window       → 2026-03-09..2026-03-18
#     (5 flights with price ≥ 70 AND time_comfort ≥ 70)
#   price_rarity.classification   → :below_median
#     (all-flights median = 23 000, between p25 and p50)

insights_a = Search::Insights::Builder.call(
  ranked_flights: all_ranked,
  snapshot:       snapshot(confidence: :high, volatility: :low),
  intent:         nil
)
print_insights("SCENARIO A — High confidence · Low volatility · Cheap prices", insights_a)

# ─── Scenario B: High volatility overrides cheap prices ───────────────────────
#
# Same flights and scores; only volatility changes to :high.
#
# Expected:
#   wait_or_book.directive        → :wait
#     (rule 3: high volatility wins, even though prices are below p25)
#   best_time_to_travel           → week of 2026-03-09 (confidence still :high)
#   cheapest_comfort_window       → still populated (confidence :high)
#   price_rarity                  → still :below_median

insights_b = Search::Insights::Builder.call(
  ranked_flights: all_ranked,
  snapshot:       snapshot(confidence: :high, volatility: :high),
  intent:         nil
)
print_insights("SCENARIO B — High confidence · HIGH volatility · Cheap prices", insights_b)

# ─── Scenario C: Low confidence ───────────────────────────────────────────────
#
# Expected:
#   wait_or_book.directive        → :insufficient_data  (low confidence → rule 1)
#   best_time_to_travel           → nil   (suppressed by low confidence gate)
#   cheapest_comfort_window       → nil   (suppressed by low confidence gate)
#   price_rarity                  → nil   (suppressed by low confidence gate)

insights_c = Search::Insights::Builder.call(
  ranked_flights: all_ranked,
  snapshot:       snapshot(confidence: :low, volatility: :low),
  intent:         nil
)
print_insights("SCENARIO C — LOW confidence (all date-range insights suppressed)", insights_c)

# ─── Scenario D: Medium confidence, prices in consider-booking zone ───────────
#
# Medium confidence + prices below_median → :consider_booking (rule 5).
# Top-3 flights priced at 220–240 USD (between p25=200 and p50=300).
#
# Expected:
#   wait_or_book.directive        → :consider_booking
#   best_time_to_travel           → present (medium confidence allows it)
#   price_rarity.classification   → :below_median

flights_mid = [
  flight(departure_date: "2026-03-09", price_cents: 22_000),
  flight(departure_date: "2026-03-11", price_cents: 23_000),
  flight(departure_date: "2026-03-13", price_cents: 24_000),
  flight(departure_date: "2026-03-16", price_cents: 32_000),
  flight(departure_date: "2026-03-18", price_cents: 33_000),
  flight(departure_date: "2026-03-20", price_cents: 34_000)
]
scores_mid = [
  score(value: 82, price: 78, time_comfort: 80, trip_fit: 75),
  score(value: 80, price: 76, time_comfort: 79, trip_fit: 74),
  score(value: 78, price: 74, time_comfort: 78, trip_fit: 72),
  score(value: 68, price: 65, time_comfort: 70, trip_fit: 62),
  score(value: 65, price: 63, time_comfort: 68, trip_fit: 60),
  score(value: 62, price: 60, time_comfort: 65, trip_fit: 58)
]
ranked_mid = flights_mid.each_with_index.map do |f, i|
  ranked(flight: f, score_result: scores_mid[i], rank: i + 1)
end

insights_d = Search::Insights::Builder.call(
  ranked_flights: ranked_mid,
  snapshot:       snapshot(confidence: :medium, volatility: :low),
  intent:         nil
)
print_insights("SCENARIO D — Medium confidence · Low volatility · Below-median prices", insights_d)

puts "\n" + ("=" * 70)
puts "  Done. Check each 'Expected:' comment against the output above."
puts "=" * 70 + "\n"
