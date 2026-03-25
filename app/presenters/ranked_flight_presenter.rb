# frozen_string_literal: true

class RankedFlightPresenter
  TAG_COLOR_CLASSES = {
    top_rated: "bg-brand-50 text-brand-700",
    best_price: "bg-emerald-50 text-emerald-600",
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
    I18n.t("flights.tags.#{tag}")
  end

  def tag_color_class(tag)
    TAG_COLOR_CLASSES[tag]
  end

  def score
    score_result.value.round
  end

  def score_label
    case score_result.value
    when 80..100 then I18n.t("flights.score_labels.excellent")
    when 60..79 then I18n.t("flights.score_labels.good")
    when 40..59 then I18n.t("flights.score_labels.fair")
    else I18n.t("flights.score_labels.poor")
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
    when 0 then I18n.t("flights.stops.direct")
    when 1 then I18n.t("flights.stops.one_stop")
    else I18n.t("flights.stops.many_stops", count: flight.stops)
    end
  end

  def stops_color_class
    flight.stops.zero? ? "text-emerald-600 font-medium" : "text-gray-500"
  end

  def luggage_label
    key = flight.luggage_included? ? "included" : "carry_on_only"
    I18n.t("flights.luggage.#{key}")
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

  def search_urls
    return nil unless @intent

    FlightSearchUrlBuilder.call(
      origin: @intent.origin_airport,
      destination: @intent.destination_airport,
      departure_date: flight.departure_datetime.to_date,
      return_date: flight.return_datetime.to_date
    )
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

  private

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
    PriceFormatter.call(cents, flight.currency)
  end
end
