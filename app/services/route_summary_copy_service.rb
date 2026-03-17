# frozen_string_literal: true

class RouteSummaryCopyService
  MODEL = "claude-haiku-4-5-20251001"
  CACHE_TTL = 7.days

  SYSTEM_PROMPT = <<~SYSTEM.strip
    You write short, honest route summaries for travelers deciding whether to book
    a flight. Use plain, conversational language. Use specific dollar amounts.
    Avoid raw percentages. Use ONLY the numbers provided — never invent statistics.
  SYSTEM

  RULES_TEXT = <<~TEXT.strip
    RULES
    - 2–3 sentences max
    - Answer at least 2 of these questions:
        (1) How do current prices compare to what's typical for this route?
        (2) What does the price volatility suggest about waiting vs. booking?
        (3) Is this a good time to act, or should the traveler hold off?
    - Use qualitative labels for price position: "rare deal", "below average",
      "above average", "expensive" — with $ amounts for context
    - For volatility: LOW → "prices are stable", MEDIUM → "prices can shift",
      HIGH → "prices on this route are unpredictable"
    - When directive is book_now and price is cheap or rare_cheap → convey urgency
    - When directive is wait and price is above average or expensive → advise patience
    - When confidence is MEDIUM → soften language slightly ("appears to be", "tends to")
    - Never use em dashes (—) or semicolons (;) — rewrite the sentence instead
    - Output only the narrative text, no JSON, no bullets
  TEXT

  def self.call(insights:, snapshot:, intent: nil)
    new(insights, snapshot, intent).call
  end

  def initialize(insights, snapshot, intent)
    @insights = insights
    @snapshot = snapshot
    @intent = intent
  end

  def call
    return nil if @snapshot.confidence == :low
    return nil unless data_sufficient?

    api_key = Rails.application.credentials.anthropic_api_key
    return nil unless api_key

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_from_api(api_key) }
  rescue StandardError
    nil
  end

  private

  def data_sufficient?
    @snapshot.price_distribution_present? && @insights.wait_or_book
  end

  def fetch_from_api(api_key)
    client = Anthropic::Client.new(api_key: api_key)
    message = client.messages.create(
      model: MODEL,
      max_tokens: 200,
      system: SYSTEM_PROMPT,
      messages: [ { role: "user", content: user_prompt } ]
    )

    text = message.content.find { |b| b.type == :text }&.text
    text&.strip
  rescue StandardError
    nil
  end

  def user_prompt
    <<~PROMPT.strip
      ROUTE DATA
      #{route_data_lines}

      #{RULES_TEXT}
    PROMPT
  end

  def route_data_lines
    wob = @insights.wait_or_book
    rarity = @insights.price_rarity

    lines = [
      "- Route median price: #{format_price(@snapshot.price_p50_cents)} | p25: #{format_price(@snapshot.price_p25_cents)} | p75: #{format_price(@snapshot.price_p75_cents)}",
      "- Volatility: #{@snapshot.volatility.to_s.upcase}",
      "- Confidence: #{@snapshot.confidence.to_s.upcase} (#{@snapshot.sample_count} samples)"
    ]

    if wob
      lines << "- Best available price (top options): #{format_price(wob.top_flight_median_price_cents)}"
      lines << "- Price band: #{wob.price_band}"
      lines << "- Booking directive: #{wob.directive}"
    end

    if rarity
      lines << "- Price rarity classification: #{rarity.classification}"
    end

    lines.join("\n")
  end

  def format_price(cents)
    return "N/A" unless cents

    "$#{(cents / 100.0).round}"
  end

  def cache_key
    wob = @insights.wait_or_book
    parts = [
      "route_summary/v2",
      @snapshot.price_p50_cents,
      @snapshot.volatility,
      wob&.directive,
      wob&.price_band
    ]
    parts.join("/")
  end
end
