# frozen_string_literal: true

class RankedFlightPresenter
  TAG_LABELS = {
    top_rated:    "Top rated",
    best_price:   "Best price",
    best_comfort: "Best comfort"
  }.freeze

  TAG_COLOR_CLASSES = {
    top_rated:    "bg-indigo-50 text-indigo-600",
    best_price:   "bg-emerald-50 text-emerald-600",
    best_comfort: "bg-blue-50 text-blue-600"
  }.freeze

  def initialize(ranked_flight, intent: nil, total_flights: nil, ai_copy: nil, tags: [])
    @ranked_flight = ranked_flight
    @intent = intent
    @total_flights = total_flights
    @precomputed_ai_copy = ai_copy
    @tags = Array(tags)
  end

  def rank
    @ranked_flight.rank
  end

  def tags
    @tags
  end

  def tag_label(tag)
    TAG_LABELS[tag]
  end

  def tag_color_class(tag)
    TAG_COLOR_CLASSES[tag]
  end

  def score
    score_result.value.round
  end

  def score_label
    case score_result.value
    when 80..100 then "Excellent"
    when 60..79 then "Good"
    when 40..59 then "Fair"
    else "Poor"
    end
  end

  def score_color_class
    case score_result.value
    when 80..100 then "text-emerald-600"
    when 60..79 then "text-blue-600"
    when 40..59 then "text-yellow-600"
    else "text-red-500"
    end
  end

  def score_ring_class
    case score_result.value
    when 80..100 then "ring-emerald-200 bg-emerald-50"
    when 60..79 then "ring-blue-200 bg-blue-50"
    when 40..59 then "ring-yellow-200 bg-yellow-50"
    else "ring-red-200 bg-red-50"
    end
  end

  def price
    format_price(flight.price_cents)
  end

  def departure_date
    flight.departure_datetime.strftime("%b %-d")
  end

  def return_date
    flight.return_datetime.strftime("%b %-d")
  end

  def stay_days
    flight.stay_length_days
  end

  def duration
    total = (flight.air_time_minutes || 0) + (flight.layover_time_minutes || 0)
    "#{total / 60}h #{total % 60}m"
  end

  def stops_label
    case flight.stops
    when 0 then "Direct"
    when 1 then "1 stop"
    else "#{flight.stops} stops"
    end
  end

  def stops_color_class
    flight.stops.zero? ? "text-emerald-600 font-medium" : "text-gray-500"
  end

  def luggage_label
    flight.luggage_included? ? "Luggage included" : "Carry-on only"
  end

  def luggage_included_class
    flight.luggage_included? ? "text-emerald-600" : "text-gray-400"
  end

  def summary
    @precomputed_ai_copy&.dig(:summary)
  end

  def tradeoffs
    @precomputed_ai_copy&.dig(:tradeoffs) || []
  end

  def skip_reason
    @precomputed_ai_copy&.dig(:skip_reason)
  end

  def price_score
    score_result.components[:price]&.round
  end

  def comfort_score
    score_result.components[:time_comfort]&.round
  end

  def trip_fit_score
    score_result.components[:trip_fit]&.round
  end

  EXPLANATION_KEY_LABELS = {
    strong_price:        "Great value — price is the main reason this scores well.",
    strong_time_comfort: "Comfortable journey — routing and travel time are the main strengths.",
    strong_trip_fit:     "Fits your trip requirements well.",
    cheap_but_longer:    "Cheaper than average, but the journey takes longer.",
    fast_but_expensive:  "Faster than average, but costs more."
  }.freeze

  DIMENSION_LABELS = {
    price:        "Scores mainly on price.",
    time_comfort: "Scores mainly on journey comfort and duration.",
    trip_fit:     "Scores mainly on how well it fits your trip."
  }.freeze

  TRADEOFF_LABELS = {
    cheap_but_longer:   "Cheaper than average, but the journey takes longer.",
    fast_but_expensive: "Faster than average, but costs more."
  }.freeze

  private

  def template_summary
    return nil unless explanation&.summary

    keys = explanation.summary[:explanation_keys] || []
    primary = explanation.summary[:primary_factors] || []

    if keys.any?
      EXPLANATION_KEY_LABELS[keys.first]
    else
      DIMENSION_LABELS[primary.first]
    end
  end

  def template_tradeoffs
    return [] unless explanation&.tradeoffs

    explanation.tradeoffs.filter_map { |t| TRADEOFF_LABELS[t[:explanation_key]] }
  end

  def flight
    @ranked_flight.flight
  end

  def score_result
    @ranked_flight.score_result
  end

  def explanation
    @ranked_flight.explanation
  end

  def format_price(cents)
    return "N/A" unless cents

    "$#{(cents / 100.0).round}"
  end
end
