# frozen_string_literal: true
#
# Full pipeline console test — no real provider needed.
# Seeds AR records, injects a mock provider, runs the complete 8-phase
# pipeline, and prints ranked flights + all four insight artifacts.
#
# Run from the Rails console:
#   load Rails.root.join("script/pipeline_console_test.rb")

puts "\n" + ("=" * 70)
puts "  Full Pipeline — End-to-End Console Test"
puts "=" * 70

# ─── 1. Seed AR records ───────────────────────────────────────────────────────
#
# SearchIntent has a unique index on (origin_airport, destination_airport),
# so find_or_initialize_by + save! is safe to run multiple times.

user = User.find_or_create_by!(email: "pipeline_test@example.com")

intent = SearchIntent.find_or_initialize_by(
  origin_airport:      "JFK",
  destination_airport: "CDG"
)
intent.assign_attributes(
  user:                user,
  earliest_departure:  Date.today + 14,
  latest_return:       Date.today + 56,
  min_stay_days:       5,
  max_stay_days:       10,
  luggage_requirement: :carry_on,
  max_stops:           1
)
intent.save!

run = SearchRun.create!(search_intent: intent, state: :initialized)
puts "\nCreated SearchRun ##{run.id}  (state: #{run.state})"
puts "Intent: #{intent.origin_airport} → #{intent.destination_airport}"
puts "Window: #{intent.earliest_departure} to #{intent.latest_return}"

# ─── 2. Mock provider ─────────────────────────────────────────────────────────
#
# Returns 3 flights per date pair. Adds a day-of-week offset to price_cents
# so the spread across sample dates is realistic (low volatility, clear tiers).
#
# All keys in Sampler::REQUIRED_KEYS are present.

mock_provider = Object.new
def mock_provider.search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
  day_offset = departure_date.wday * 1_500  # Mon 0 → Sun 9_000 cents variation

  [
    { price_cents:          38_000 + day_offset,
      currency:             "USD",
      airline_codes:        ["AA"],
      stops:                0,
      air_time_minutes:     415,
      layover_time_minutes: 0,
      luggage_included:     true,
      raw_provider:         "mock" },
    { price_cents:          44_000 + day_offset,
      currency:             "USD",
      airline_codes:        ["BA"],
      stops:                1,
      air_time_minutes:     530,
      layover_time_minutes: 85,
      luggage_included:     false,
      raw_provider:         "mock" },
    { price_cents:          52_000 + day_offset,
      currency:             "USD",
      airline_codes:        ["AF"],
      stops:                0,
      air_time_minutes:     420,
      layover_time_minutes: 0,
      luggage_included:     true,
      raw_provider:         "mock" }
  ]
end

# ─── 3. Run the full pipeline ─────────────────────────────────────────────────
#
# max_candidates: 8 → 8 date pairs × 3 flights = up to 24 samples.
# That exceeds the high-confidence threshold (≥20) in SnapshotBuilder.

puts "\nRunning pipeline (max_candidates: 8)..."

begin
  execution = Search::Repositories::SearchRunRepository.execute(
    run,
    provider:       mock_provider,
    max_candidates: 8,
    passengers:     1,
    cabin_class:    :economy
  )

  run.reload

  # ─── 4. Persistence check ────────────────────────────────────────────────────

  puts "\nSearchRun state:       #{run.state}"
  puts "FlightSamples in DB:   #{FlightSample.where(search_run: run).count}"

  snapshot_ar = run.analysis_snapshot
  if snapshot_ar
    puts "\nAnalysisSnapshot:"
    puts "  p25 = $#{snapshot_ar.price_p25_cents / 100}"
    puts "  p50 = $#{snapshot_ar.price_p50_cents / 100}"
    puts "  p75 = $#{snapshot_ar.price_p75_cents / 100}"
    puts "  confidence = #{snapshot_ar.confidence_level}"
    puts "  sample_size = #{snapshot_ar.sample_size}"
  else
    puts "\nNo AnalysisSnapshot persisted (too few samples)."
  end

  # ─── 5. Ranked flights ───────────────────────────────────────────────────────

  puts "\nTop 5 ranked flights:"
  puts "-" * 60
  execution.ranked_results.first(5).each do |rf|
    dep   = rf.flight.departure_datetime.strftime("%Y-%m-%d")
    price = rf.flight.price_cents
    puts "  ##{rf.rank} | #{dep} | #{rf.flight.stops} stop(s) | $#{price / 100} | score=#{rf.score_result.value}"
  end

  # ─── 6. Insights ─────────────────────────────────────────────────────────────

  insights = execution.insights
  if insights
    puts "\nInsights:"
    puts "-" * 60
    puts "  confidence_level:      #{insights.confidence_level}"

    wob = insights.wait_or_book
    puts "  wait_or_book:          #{wob.directive}"
    puts "    price_band:          #{wob.price_band.inspect}"
    puts "    top_median_price:    $#{wob.top_flight_median_price_cents.to_i / 100}" if wob.top_flight_median_price_cents

    btt = insights.best_time_to_travel
    if btt
      puts "  best_time_to_travel:   #{btt.from_date} → #{btt.to_date}"
      puts "    avg score:           #{btt.average_score.round(1)}"
      puts "    flights:             #{btt.flight_count}"
    else
      puts "  best_time_to_travel:   nil"
    end

    ccw = insights.cheapest_comfort_window
    if ccw
      puts "  cheapest_comfort_win:  #{ccw.from_date} → #{ccw.to_date}"
      puts "    avg score:           #{ccw.average_score.round(1)}"
      puts "    flights:             #{ccw.flight_count}"
    else
      puts "  cheapest_comfort_win:  nil"
    end

    pr = insights.price_rarity
    if pr
      puts "  price_rarity:          #{pr.classification}"
      puts "    market median:       $#{pr.market_representative_price_cents / 100}"
    else
      puts "  price_rarity:          nil"
    end
  else
    puts "\nNo insights generated (insufficient data or no snapshot)."
  end

rescue => e
  puts "\nPipeline FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(8).join("\n")

  run.reload
  puts "\nSearchRun state: #{run.state}"
  puts "Error message:   #{run.error_message}"
end

puts "\n" + ("=" * 70)
puts "  Done."
puts "=" * 70 + "\n"
