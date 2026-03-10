# AI-Powered Flight Explanation Copy

## Context

Current flight explanations are static label lookups in `RankedFlightPresenter` — one-liner strings like "Great value — price is the main reason this scores well." These are generic, numberless, and disconnected from the user's decision. The domain layer already produces rich structured data (price delta from median, baseline deviations, tradeoffs, volatility) but the presenter ignores it.

The goal is to replace the static labels with AI-generated copy that is:

- **Quantitative**: "$130 below the market median" not "great value"
- **Volatility-aware**: tone shifts based on market stability
- **Honest about weak options**: flights with no compensating strength get a "why skip this" framing
- **Subtly intent-aware**: references luggage and stops in context

Anti-hallucination guarantee: the prompt passes every number explicitly. Claude has nothing to invent.

Copy is generated at render-time (not stored in DB) so that as market baselines evolve across accumulated searches, explanations stay current. A smart cache key (embedding price median + volatility) ensures invalidation when market conditions change. Template-based copy remains as fallback if the API is unavailable.

---

## Architecture

**New service**: `app/services/explanation_copy_service.rb`
Called from presenter → wraps `Rails.cache.fetch` → calls Claude Haiku 4.5 → returns structured hash.

**Layer placement**: Presentation layer only. No domain changes. No storage.

**Model**: `claude-haiku-4-5` — adequate for structured generation from explicit data, cheap at scale (~$0.01 per 30-flight search).

---

## Files to Modify

| File                                         | Change                                                |
| -------------------------------------------- | ----------------------------------------------------- |
| `Gemfile`                                    | Add `gem "anthropic"`                                 |
| `app/services/explanation_copy_service.rb`   | **NEW** — Claude call + caching                       |
| `app/presenters/search_results_presenter.rb` | Pass `search_intent` to `RankedFlightPresenter`       |
| `app/presenters/ranked_flight_presenter.rb`  | Use service for `summary`, `tradeoffs`, `skip_reason` |
| `app/views/searches/_flight_card.html.erb`   | Render `skip_reason` when present                     |

---

## Implementation Steps

### 1. Gemfile

```ruby
gem "anthropic"
```

API key via Rails credentials: `Rails.application.credentials.anthropic_api_key`
Service returns `nil` (falls back to templates) when key is absent.

---

### 2. ExplanationCopyService (`app/services/explanation_copy_service.rb`)

**Interface:**

```ruby
ExplanationCopyService.call(ranked_flight:, intent:)
# Returns: { summary: String, tradeoffs: [String], skip_reason: String|nil }
# Returns nil on error or missing API key → presenter falls back to templates
```

**Cache key** (market-state-aware — invalidates when baselines shift):

```
explanation_copy/v1/{flight_id}/{price_median_cents}/{volatility}
```

TTL: 7 days.

**Prompt strategy** — structured data block, no ambiguity:

```
SYSTEM: You write short, honest flight explanations for travelers. Use ONLY the
numbers provided. Never invent or imply statistics not listed below.

USER:
FLIGHT DATA
- Rank: #1 of 15
- Price: $855 | Market median: $985 | Delta: $130 below (13% cheaper)
- Travel time: 35h 35m | Route median: 38h | Delta: 6% shorter
- Stops: 2 | User max: 2 (at limit)
- Luggage: carry-on only | User requires: checked
- Scores → Price: 100 | Comfort: 70 | Trip fit: 77 | Final: 79
- Price vs market: BETTER | Duration vs median: NEUTRAL
- Market volatility: HIGH

RULES
- 2 sentences max for summary
- Reference specific numbers; avoid vague language
- If volatility is HIGH and price is BETTER → note urgency ("don't wait")
- If volatility is HIGH and price is WORSE → note possibility of better prices
- If price is WORSE and no dimension is BETTER → set skip_reason explaining why
- Luggage mismatch (user needs checked, flight has carry-on only) → flag it
- If stops equal user max → note "at your stop limit"

OUTPUT FORMAT (JSON only, no other text):
{
  "summary": "...",
  "tradeoffs": ["..."],
  "skip_reason": null
}
```

Parse the JSON response. On any error (API down, parse failure, missing key) → return `nil`.

**Skip reason trigger** (computed before API call, passed to prompt):

- Price `relative_to_baseline` is `:worse`
- AND no dimension has `relative_to_baseline: :better`

---

### 3. SearchResultsPresenter — pass intent

```ruby
def ranked_flights
  intent = @search_run.search_intent
  @ranked_flights ||= @results.ranked_flights.map { |rf|
    RankedFlightPresenter.new(rf, intent: intent)
  }
end
```

---

### 4. RankedFlightPresenter — use service

```ruby
def initialize(ranked_flight, intent: nil)
  @ranked_flight = ranked_flight
  @intent = intent
end

def summary
  ai_copy&.dig(:summary) || template_summary
end

def tradeoffs
  ai_copy&.dig(:tradeoffs) || template_tradeoffs
end

def skip_reason
  ai_copy&.dig(:skip_reason)
end

private

def ai_copy
  return nil unless explanation
  @ai_copy ||= ExplanationCopyService.call(ranked_flight: @ranked_flight, intent: @intent)
end
```

Keep existing `template_summary` and `template_tradeoffs` (renamed from current `summary`/`tradeoffs`) as fallback.

---

### 5. Flight card — skip reason

In `_flight_card.html.erb`, add inside the explanation box:

```erb
<% if flight.skip_reason.present? %>
  <p class="mt-2 text-xs text-amber-600 font-medium"><%= flight.skip_reason %></p>
<% end %>
```

---

## Data Available to the Prompt

All sourced from `ranked_flight` — no additional queries:

| Data point                           | Source                                      |
| ------------------------------------ | ------------------------------------------- |
| Price, stops, luggage, times         | `ranked_flight.flight` (FlightSample)       |
| Price median, volatility, confidence | `ranked_flight.explanation.baselines`       |
| Per-dimension relative_to_baseline   | `ranked_flight.explanation.score_breakdown` |
| Component scores                     | `ranked_flight.score_result.components`     |
| Rank                                 | `ranked_flight.rank`                        |
| Total flights in set                 | passed from presenter context               |
| Luggage requirement, max stops       | `intent` (SearchIntent AR model)            |

---

## Fallback Behavior

| Condition                          | Result                           |
| ---------------------------------- | -------------------------------- |
| `ANTHROPIC_API_KEY` not configured | Returns nil → template copy      |
| Claude API error / timeout         | Returns nil → template copy      |
| JSON parse failure                 | Returns nil → template copy      |
| Cache hit                          | Returns cached copy, no API call |

---

## Verification

1. Set `anthropic_api_key` in Rails credentials
2. Load a completed search run in console → render via presenter
3. Confirm: summary contains dollar amounts, no invented stats
4. Confirm: high-volatility + cheap flight → urgency language
5. Confirm: flight with price `:worse` and no `:better` dimension → `skip_reason` populated
6. Confirm: remove API key → falls back to template labels (no error)
7. Confirm: second render for same flight → cache hit (no API call logged)
8. Run `bundle exec rspec spec/presenters/` if presenter specs exist

---

## Future Directions

- **Route-level baselines**: As `flight_samples` accumulates data across multiple searches for the same route, baselines become more statistically significant. The `AnalysisSnapshot` can eventually draw from historical samples rather than just the current run — at which point the cache key and explanation context will naturally reflect richer market data.
- **User-provided API key**: Allow users to bring their own Anthropic key for personalized explanation generation.
- **Confidence-gated copy**: When confidence is `:low`, soften the language ("prices appear to be..." vs "prices are...").
