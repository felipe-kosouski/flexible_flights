# Curated Flight Explanations

## Problem

`ExplanationCopyService` makes one synchronous Claude API call per rendered flight. With 20 candidates (default `max_candidates`), the show page triggers up to 20 sequential HTTP requests at render time → unacceptably slow.

---

## Product Decision

Not every flight deserves a narrative. Only a small curated set of decision-relevant flights gets AI-generated explanations. All other flights show their score breakdown numbers only — no explanation box.

This also clarifies the UX intent: the explanations highlight the flights worth considering, not a comprehensive breakdown of all options.

---

## Curated Selection Strategy

Pick up to 5 flights (deduped with `.uniq`):

| Slot         | Selection criterion                                 | Why                                |
| ------------ | --------------------------------------------------- | ---------------------------------- |
| Top 3        | First 3 by final score (already ranked)             | The most decision-relevant options |
| Best price   | `max_by { score_result.components[:price] }`        | Cheapest relative to market        |
| Best comfort | `max_by { score_result.components[:time_comfort] }` | Smoothest journey                  |

If best-price or best-comfort is already in the top 3, the set stays ≤ 5.

---

## Architecture

### API calls at render time

| Before                           | After                         |
| -------------------------------- | ----------------------------- |
| Up to 20 sequential Claude calls | 1 batch call (0 on cache hit) |

### Flow

```
SearchResultsPresenter#ranked_flights
  → curated_flights     (select ≤ 5 domain objects)
  → batch_ai_copy       (1 Claude call → hash keyed by fingerprint)
  → map all flights to RankedFlightPresenter
      ↳ curated flights receive ai_copy: { summary:, tradeoffs:, skip_reason: }
      ↳ non-curated flights receive ai_copy: nil → no explanation box rendered
```

---

## Implementation Plan

### 1. `app/services/explanation_copy_service.rb`

**Add `fingerprint_for(ranked_flight)` as a public class method**

Extract the per-flight identity used for caching:

```ruby
def self.fingerprint_for(ranked_flight)
  baselines = ranked_flight.explanation.baselines
  [
    ranked_flight.flight.price_cents,
    ranked_flight.flight.departure_datetime.to_i,
    baselines[:price_median_cents],
    baselines[:volatility]
  ].join("/")
end
```

**Add `batch_call(ranked_flights:, intent:, total_flights:)`**

- Cache key: `"explanation_copy/batch/v1/#{fingerprints.sort.join('|')}"` (sorted for stability), TTL 7 days
- Builds a single prompt with N flight data blocks, each tagged with its fingerprint as `"id":`
- Returns a `Hash` keyed by fingerprint → `{ summary:, tradeoffs:, skip_reason: }` (symbol keys)
- Returns `{}` on any error — fallback is graceful (no AI copy rendered)
- `max_tokens: 256 * ranked_flights.size`

**Prompt structure**

```
FLIGHTS
=======

FLIGHT (id: <fingerprint>)
- Rank: #1 of 18
- Price: $342 | Market median: $410 | Delta: $68 below (17% cheaper)
... (same fields as existing user_prompt)

FLIGHT (id: <fingerprint>)
...

RULES
(same rules as existing prompt)

OUTPUT FORMAT (JSON array, no other text):
[
  { "id": "<fingerprint>", "summary": "...", "tradeoffs": ["..."], "skip_reason": null },
  ...
]
```

Using `"id"` in the response lets the parser build the fingerprint-keyed hash without relying on positional matching.

**Keep existing `call` method intact** — not wired up to any live call path after this change, but preserved as a backward-compatible fallback.

---

### 2. `app/presenters/search_results_presenter.rb`

```ruby
def ranked_flights
  intent = @search_run.search_intent
  total  = @results.ranked_flights.size
  copy   = batch_ai_copy

  @ranked_flights ||= @results.ranked_flights.map { |rf|
    fingerprint = ExplanationCopyService.fingerprint_for(rf)
    RankedFlightPresenter.new(rf, intent: intent, total_flights: total, ai_copy: copy[fingerprint])
  }
end

private

def curated_flights
  all = @results.ranked_flights
  top3         = all.first(3)
  best_price   = all.max_by { |rf| rf.score_result.components[:price].to_f }
  best_comfort = all.max_by { |rf| rf.score_result.components[:time_comfort].to_f }
  (top3 + [best_price, best_comfort].compact).uniq
end

def batch_ai_copy
  @batch_ai_copy ||= ExplanationCopyService.batch_call(
    ranked_flights: curated_flights,
    intent: @search_run.search_intent,
    total_flights: @results.ranked_flights.size
  )
end
```

---

### 3. `app/presenters/ranked_flight_presenter.rb`

- Add `ai_copy: nil` keyword arg to constructor
- Replace lazy `ai_copy` private method with `@precomputed_ai_copy` (no service call)
- `summary` returns `ai_copy&.dig(:summary)` only — **no template fallback**
- `tradeoffs` returns `ai_copy&.dig(:tradeoffs) || []` — **no template fallback**
- Keep `template_summary` and `template_tradeoffs` as private dead code (don't delete — useful if a no-API fallback mode is added later)

Non-curated flights receive `ai_copy: nil` → `summary` is nil → the view guard hides the explanation box.

---

### 4. `app/views/searches/_flight_card.html.erb`

No changes. The existing guard `<% if flight.summary.present? || flight.tradeoffs.present? %>` already handles hiding the explanation box when both are blank.

---

## Files Modified

| File                                         | Change                                                                                |
| -------------------------------------------- | ------------------------------------------------------------------------------------- |
| `app/services/explanation_copy_service.rb`   | Add `fingerprint_for` + `batch_call`                                                  |
| `app/presenters/search_results_presenter.rb` | Add `curated_flights`, `batch_ai_copy`; update `ranked_flights`                       |
| `app/presenters/ranked_flight_presenter.rb`  | Accept `ai_copy:`, remove service call, drop template fallbacks from public interface |
| `app/views/searches/_flight_card.html.erb`   | No change                                                                             |

---

## Pagination Compatibility

This change is pagination-ready. When pagination is added later:

- Pass only the current page's flights to `batch_ai_copy`
- `curated_flights` selection logic can stay or be removed — the page slice itself becomes the curated set
- No changes needed to `ExplanationCopyService`

---

## Verification

```ruby
run = SearchRun.completed.last
results = Search::Repositories::SearchRunRepository.load_results(run)
presenter = SearchResultsPresenter.new(results, run)

flights = presenter.ranked_flights
curated = flights.select { |f| f.summary.present? }

puts "Curated: #{curated.size} / #{flights.size}"  # expect ≤ 5
puts curated.first.summary     # should contain dollar amounts
puts curated.first.tradeoffs
puts curated.first.skip_reason
puts flights.last.summary      # should be nil
```

Also confirm:

- No API key → `batch_call` returns `{}` → all flights show no explanation box, no error
- Second render → cache hit, no API call logged
