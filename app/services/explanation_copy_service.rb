# frozen_string_literal: true

class ExplanationCopyService
  MODEL = "claude-haiku-4-5-20251001"
  CACHE_TTL = 7.days

  SYSTEM_PROMPT = <<~SYSTEM.strip
    You write short, honest flight explanations for travelers that read like
    advice from a knowledgeable friend. Translate numbers into meaning. Use
    specific dollar amounts. Avoid raw percentages for travel time — describe
    what they mean instead (e.g., "about 2 hours longer than typical" not
    "17% longer than median"). Use ONLY the numbers provided. Never invent or
    imply statistics not listed below.
  SYSTEM

  RULES_TEXT = <<~TEXT.strip
    RULES
    - 2 sentences max for summary
    - Every summary must answer at least 2 of these questions:
        (1) How does this compare to the market? (price position, route speed)
        (2) What does price history suggest? (volatility signal)
        (3) Is there urgency to act now?
    - Lead with the most decision-relevant fact
    - For price: use $ amounts + qualitative label (e.g. "one of the cheapest at $536", "above average at $620")
    - For travel time: describe difference in plain words — hours saved/added, or relative terms
        like "among the fastest", "much longer than typical". Do NOT say "X% faster/slower".
    - If volatility is HIGH and price is BETTER → note urgency ("prices on this route swing — this won't last")
    - If volatility is HIGH and price is WORSE → note possibility of better prices appearing
    - If price is WORSE and no dimension is BETTER → set skip_reason explaining why
    - Luggage mismatch (user needs checked, flight has carry-on only) → flag it in tradeoffs
    - If stops equal user max → note "at your stop limit" in tradeoffs
    - If skip_reason does not apply, set it to null
    - Never use em dashes (—) or semicolons (;) — rewrite the sentence instead
  TEXT

  def self.call(ranked_flight:, intent:, total_flights: nil)
    new(ranked_flight, intent, total_flights).call
  end

  def self.fingerprint_for(ranked_flight)
    baselines = ranked_flight.explanation.baselines
    [
      ranked_flight.rank,
      ranked_flight.flight.price_cents,
      ranked_flight.flight.departure_datetime.to_i,
      ranked_flight.flight.return_datetime.to_i,
      baselines[:price_median_cents],
      baselines[:volatility]
    ].join("/")
  end

  def self.batch_call(ranked_flights:, intent:, total_flights:)
    return {} if ranked_flights.empty?

    api_key = Rails.application.credentials.anthropic_api_key
    return {} unless api_key

    fingerprints = ranked_flights.map { |rf| fingerprint_for(rf) }
    cache_key = "explanation_copy/batch/v3/#{fingerprints.sort.join('|')}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      pairs = ranked_flights.zip(fingerprints).filter_map { |rf, fp|
        instance = new(rf, intent, total_flights)
        next unless instance.send(:explanation)

        [ instance, fp ]
      }

      next({}) if pairs.empty?

      sections = pairs.map { |instance, fp| instance.send(:flight_prompt_block, fp) }
      batch_fetch_from_api(api_key, sections, pairs.size)
    end
  rescue StandardError
    {}
  end

  private_class_method def self.batch_fetch_from_api(api_key, flight_sections, count)
    prompt = build_batch_prompt(flight_sections)
    client = Anthropic::Client.new(api_key: api_key)
    message = client.messages.create(
      model: MODEL,
      max_tokens: 256 * count,
      system: SYSTEM_PROMPT,
      messages: [ { role: "user", content: prompt } ]
    )

    text = message.content.find { |b| b.type == :text }&.text
    return {} unless text

    parse_batch_response(text)
  rescue StandardError
    {}
  end

  private_class_method def self.build_batch_prompt(flight_sections)
    <<~PROMPT.strip
      FLIGHTS
      =======

      #{flight_sections.join("\n\n")}

      #{RULES_TEXT}

      OUTPUT FORMAT (JSON array, no other text):
      [
        { "id": "<fingerprint>", "summary": "...", "tradeoffs": ["..."], "skip_reason": null },
        ...
      ]
    PROMPT
  end

  private_class_method def self.parse_batch_response(text)
    cleaned = text.gsub(/\A```(?:json)?\s*/, "").gsub(/\s*```\z/, "").strip
    parsed = JSON.parse(cleaned, symbolize_names: true)
    return {} unless parsed.is_a?(Array)

    parsed.each_with_object({}) do |entry, hash|
      id = entry[:id]
      next unless id

      hash[id] = entry.except(:id)
    end
  rescue StandardError
    {}
  end

  def initialize(ranked_flight, intent, total_flights)
    @ranked_flight = ranked_flight
    @intent = intent
    @total_flights = total_flights
  end

  def call
    api_key = Rails.application.credentials.anthropic_api_key
    return nil unless api_key && explanation

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_from_api(api_key) }
  end

  private

  def fetch_from_api(api_key)
    client = Anthropic::Client.new(api_key: api_key)
    message = client.messages.create(
      model: MODEL,
      max_tokens: 256,
      system: SYSTEM_PROMPT,
      messages: [ { role: "user", content: user_prompt } ]
    )

    text = message.content.find { |b| b.type == :text }&.text
    return nil unless text

    parsed = JSON.parse(strip_markdown(text), symbolize_names: true)
    return nil unless parsed.is_a?(Hash) && parsed.key?(:summary)

    parsed
  rescue StandardError
    nil
  end

  def strip_markdown(text)
    text.gsub(/\A```(?:json)?\s*/, "").gsub(/\s*```\z/, "").strip
  end

  def cache_key
    [
      "explanation_copy/v3",
      flight.price_cents,
      flight.departure_datetime.to_i,
      baselines[:price_median_cents],
      baselines[:volatility]
    ].join("/")
  end

  def user_prompt
    <<~PROMPT.strip
      FLIGHT DATA
      #{flight_data_lines}

      #{RULES_TEXT}

      OUTPUT FORMAT (JSON only, no other text):
      {
        "summary": "...",
        "tradeoffs": ["..."],
        "skip_reason": null
      }
    PROMPT
  end

  def flight_prompt_block(fingerprint)
    <<~BLOCK.strip
      FLIGHT (id: #{fingerprint})
      #{flight_data_lines}
    BLOCK
  end

  def flight_data_lines
    <<~DATA.strip
      - Rank: ##{rank_label}
      - Price: #{format_price(flight.price_cents)} | Market median: #{format_price(baselines[:price_median_cents])} | Delta: #{price_delta_label}
      - Travel time: #{format_duration(total_minutes)} | Route median: #{format_duration(baselines[:duration_median_minutes])} | Delta: #{duration_delta_label}
      - Stops: #{flight.stops} | User max: #{max_stops_label}
      - Luggage: #{luggage_label} | User requires: #{intent_luggage_label}
      - Scores → Price: #{price_score} | Comfort: #{comfort_score} | Trip fit: #{trip_fit_score} | Final: #{final_score}
      - Price vs market: #{dimension_status(:price)} | Duration vs median: #{dimension_status(:time_comfort)}
      - Market volatility: #{baselines[:volatility].to_s.upcase}
    DATA
  end

  def rank_label
    suffix = @total_flights ? " of #{@total_flights}" : ""
    "#{@ranked_flight.rank}#{suffix}"
  end

  def format_price(cents)
    return "N/A" unless cents

    "$#{(cents / 100.0).round}"
  end

  def price_delta_label
    median = baselines[:price_median_cents]
    return "N/A" unless median && median > 0 && flight.price_cents

    delta_cents = flight.price_cents - median
    pct = ((delta_cents.abs.to_f / median) * 100).round
    direction = delta_cents < 0 ? "below" : "above"
    qualifier = delta_cents < 0 ? "cheaper" : "more expensive"
    "$#{(delta_cents.abs / 100.0).round} #{direction} (#{pct}% #{qualifier})"
  end

  def format_duration(minutes)
    return "N/A" unless minutes

    "#{minutes / 60}h #{minutes % 60}m"
  end

  def total_minutes
    (flight.air_time_minutes || 0) + (flight.layover_time_minutes || 0)
  end

  def duration_delta_label
    median = baselines[:duration_median_minutes]
    return "N/A" unless median && median > 0 && total_minutes > 0

    pct = (((total_minutes - median).abs.to_f / median) * 100).round
    direction = total_minutes < median ? "shorter" : "longer"
    "#{pct}% #{direction}"
  end

  def max_stops_label
    return "N/A" if @intent.nil? || @intent.max_stops.nil?

    at_limit = flight.stops == @intent.max_stops ? " (at limit)" : ""
    "#{@intent.max_stops}#{at_limit}"
  end

  def luggage_label
    flight.luggage_included? ? "checked included" : "carry-on only"
  end

  def intent_luggage_label
    return "N/A" if @intent.nil?

    case @intent.luggage_requirement
    when "checked" then "checked"
    when "carry_on" then "carry-on"
    else "none"
    end
  end

  def price_score
    score_result.components[:price]&.round || "N/A"
  end

  def comfort_score
    score_result.components[:time_comfort]&.round || "N/A"
  end

  def trip_fit_score
    score_result.components[:trip_fit]&.round || "N/A"
  end

  def final_score
    score_result.value.round
  end

  def dimension_status(dimension)
    entry = score_breakdown.find { |b| b[:dimension] == dimension }
    return "N/A" unless entry

    entry[:relative_to_baseline].to_s.upcase
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

  def baselines
    explanation.baselines
  end

  def score_breakdown
    explanation.score_breakdown
  end
end
