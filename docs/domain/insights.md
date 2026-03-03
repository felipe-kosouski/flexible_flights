# Domain Spec — Insights (MVP)

**Governing documents:**

- [PRODUCT_GUIDE.md](../PRODUCT_GUIDE.md)
- [PRD.md](../PRD.md) — Smart Search Execution
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- Domain Spec — [Analysis](../domain/analysis.md)
- Domain Spec — [Scoring](../domain/scoring.md)
- Domain Spec — [Explanation](../domain/explanation.md)

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

Insights derives **decision-oriented, cross-flight conclusions** from the ranked flight list and market snapshot produced upstream.

It exists to answer the product's two primary questions (PRODUCT_GUIDE.md Section 0):

- "When is the best time to travel?"
- "Should I book now or wait?"

Insights produces **recommendations and derived artifacts**, not per-flight explanations or raw data.

---

## 2. Responsibilities

Insights MUST:

- Derive the four insight artifacts defined in PRODUCT_GUIDE.md Section 3
- Gate all directive language behind confidence rules
- Be deterministic and reproducible
- Be reusable by the presentation layer

Insights MUST NOT:

- Modify, re-sort, or re-score ranked flights
- Re-derive confidence or volatility from raw samples
- Persist data
- Perform I/O
- Depend on Rails, ActiveRecord, or I18n
- Access provider or UI concerns
- Invent insight types beyond the four defined in PRODUCT_GUIDE.md

---

## 3. Inputs

Insights receives three inputs, all assumed finalized and immutable:

- **ranked_flights** — `Array<Search::Ranking::RankedFlight>` — ordered by rank ascending; may be empty
- **snapshot** — `Search::Models::AnalysisSnapshot` — market statistics for this search run
- **intent** — `Search::Models::SearchIntent` — original user intent (read-only)

All inputs are domain objects produced upstream. Insights never reaches into ActiveRecord or raw hashes.

### RankedFlight fields consumed

| Field | Description |
| ----- | ----------- |
| `flight.price_cents` | Flight price in cents |
| `flight.departure_datetime` | Departure timestamp |
| `flight.return_datetime` | Return timestamp |
| `flight.stops` | Number of stops |
| `flight.stay_length_days` | Computed stay length |
| `score_result.value` | Final score (0–100) |
| `score_result.components[:price]` | Price dimension score (0–100) |
| `score_result.components[:time_comfort]` | Time & comfort dimension score (0–100) |
| `rank` | Integer rank (1-indexed) |

### AnalysisSnapshot fields consumed

| Field | Description |
| ----- | ----------- |
| `price_p25_cents` | 25th percentile price |
| `price_p50_cents` | Median price |
| `price_p75_cents` | 75th percentile price |
| `volatility` | `:low`, `:medium`, or `:high` |
| `confidence` | `:low`, `:medium`, or `:high` |
| `price_distribution_present?` | True if all percentile fields are populated |

---

## 4. Output — SearchInsights

Insights produces exactly **one** result object per invocation:

```ruby
Search::Insights::SearchInsights
```

The object is:

- Immutable (frozen)
- Serializable
- Safe for the presentation layer
- Not persisted

### 4.1 Attributes

| Attribute | Type | Nullable? | Description |
| --------- | ---- | --------- | ----------- |
| `best_time_to_travel` | `DateRangeInsight` or `nil` | Yes | Departure date range of the highest-scoring week cluster |
| `wait_or_book` | `WaitOrBookInsight` | No | Booking directive — always present |
| `price_rarity` | `PriceRarityInsight` or `nil` | Yes | Market price level classification |
| `cheapest_comfort_window` | `DateRangeInsight` or `nil` | Yes | Date range of flights scoring ≥ 70 on both price and time_comfort |
| `confidence_level` | `:high`, `:medium`, or `:low` | No | Inherited from snapshot |

`wait_or_book` is the only attribute that is never nil. When data is insufficient, it carries a `:insufficient_data` directive rather than being absent.

---

## 5. Confidence Gating

All four insight artifacts are subject to a single confidence rule derived from PRODUCT_GUIDE.md Section 5.

**The snapshot's `confidence` value governs directive strength across all insights.**

Confidence is inherited directly from `snapshot.confidence`. Insights never re-derives it.

| `snapshot.confidence` | Permitted `wait_or_book` directives | Date-range insights |
| --------------------- | ----------------------------------- | ------------------- |
| `:high` | All | Present if data conditions are met |
| `:medium` | `:consider_booking`, `:wait`, `:insufficient_data` | Present if data conditions are met |
| `:low` | `:insufficient_data` only | Suppressed — return `nil` |

For the three optional insight attributes (`best_time_to_travel`, `price_rarity`, `cheapest_comfort_window`), low confidence causes the attribute to return `nil` rather than a value object with a weak signal.

---

## 6. Insight 1 — best_time_to_travel

### 6.1 Purpose

Identify the departure date range that contains the cluster of highest-scoring flights.

### 6.2 Algorithm

**Step 1** — Group `ranked_flights` by ISO calendar week of `flight.departure_datetime`. Each flight belongs to exactly one bucket identified by its `year-week` (e.g., `2025-W22`).

**Step 2** — For each week bucket, compute the average `score_result.value` across all flights in that bucket.

**Step 3** — Select the bucket with the highest average score. Ties are broken by selecting the earlier week (lower ISO week number; lower year takes precedence when years differ).

**Step 4** — Within the winning bucket, find the earliest and latest `flight.departure_datetime` dates. The result spans from the earliest to the latest date, inclusive.

### 6.3 Rules

- Minimum 2 ranked flights must exist in the winning bucket. A single-flight week bucket is too thin and returns `nil`.
- If `snapshot.confidence == :low`, return `nil`.
- If `ranked_flights` is empty, return `nil`.
- Date range is expressed as calendar dates (not datetimes).

### 6.4 Example

Given ranked flights with departure dates in two weeks:

- W22: average score = 82, 4 flights (Jun 2, Jun 3, Jun 4, Jun 5)
- W23: average score = 74, 3 flights

Result: `best_time_to_travel` spans Jun 2 – Jun 5, average_score = 82, flight_count = 4.

### 6.5 Output

```ruby
Search::Insights::DateRangeInsight.new(
  from_date:        Date,     # earliest departure date in the winning cluster
  to_date:          Date,     # latest departure date in the winning cluster
  average_score:    Float,    # average final score of flights in the cluster (0–100)
  flight_count:     Integer,  # number of ranked flights in the cluster
  confidence_level: Symbol    # :high, :medium, or :low — inherited from snapshot
)
```

---

## 7. Insight 2 — wait_or_book

### 7.1 Purpose

Produce a deterministic booking directive based on the price position of the top-ranked flights and market conditions.

### 7.2 Price position of top flights

"Top-ranked flights" are the flights with `rank <= 3`, or all available ranked flights if fewer than 3 exist.

Compute the **median price** of the top flights. This is the "top-flight median price."

Classify the top-flight median price against snapshot percentile bands (same banding as `Search::Scoring::PriceScore`):

| Top-flight median price position | Band |
| -------------------------------- | ---- |
| ≤ `price_p25_cents` | `:cheap` |
| > p25 and ≤ p50 | `:below_median` |
| > p50 and ≤ p75 | `:above_median` |
| > `price_p75_cents` | `:expensive` |

### 7.3 Directive decision table

Rules are applied in priority order. **First match wins.**

| Priority | Condition | Directive |
| -------- | --------- | --------- |
| 1 | `snapshot.confidence == :low` | `:insufficient_data` |
| 2 | `ranked_flights` is empty OR `snapshot.price_distribution_present?` is false | `:insufficient_data` |
| 3 | `snapshot.volatility == :high` | `:wait` |
| 4 | `confidence == :high` AND price band `:cheap` | `:book_now` |
| 5 | price band `:cheap` OR `:below_median` AND `confidence == :medium` | `:consider_booking` |
| 6 | price band `:below_median` AND `confidence == :high` | `:consider_booking` |
| 7 | All other cases | `:wait` |

**Rule 3 note:** High volatility overrides cheap prices. When prices are unstable, the system cannot give confident timing advice regardless of the current price level. This is required by PRODUCT_GUIDE.md Section 5: "Never recommend 'book' or 'wait' with stale data."

Permitted directives by confidence level — the decision table already enforces this, but for reference:

| Directive | `:high` confidence | `:medium` confidence | `:low` confidence |
| --------- | ------------------ | -------------------- | ----------------- |
| `:book_now` | Yes | No | No |
| `:consider_booking` | Yes | Yes | No |
| `:wait` | Yes | Yes | No |
| `:insufficient_data` | Yes | Yes | Yes |

### 7.4 Examples

**Example A — Book now:**
- confidence = :high, volatility = :low
- Top-3 median price = 32,000 cents; p25 = 35,000 cents → band = :cheap
- Rule 4 matches → directive = `:book_now`

**Example B — Volatility overrides cheap prices:**
- confidence = :high, volatility = :high
- Top-3 median price = 30,000 cents (below p25) → band = :cheap
- Rule 3 fires before rule 4 → directive = `:wait`

**Example C — Medium confidence blocks :book_now:**
- confidence = :medium, volatility = :low
- Top-3 median price = 31,000 cents (below p25) → band = :cheap
- Rule 4 requires :high confidence; rule 5 applies → directive = `:consider_booking`

**Example D — Low confidence:**
- confidence = :low
- Rule 1 fires regardless of price or volatility → directive = `:insufficient_data`

### 7.5 Output

```ruby
Search::Insights::WaitOrBookInsight.new(
  directive:                       Symbol,          # :book_now | :consider_booking | :wait | :insufficient_data
  price_band:                      Symbol | nil,    # :cheap | :below_median | :above_median | :expensive; nil if no flights
  top_flight_median_price_cents:   Integer | nil,   # nil if ranked_flights is empty
  confidence_level:                Symbol           # :high, :medium, or :low — inherited from snapshot
)
```

`wait_or_book` is never nil. When inputs are missing or confidence is low, the directive is `:insufficient_data`.

---

## 8. Insight 3 — price_rarity

### 8.1 Purpose

Classify the current market price level as a named category, enabling presentation copy such as "prices are currently rare and low for this route."

### 8.2 Algorithm

Compute the **median price of all ranked flights** (not just top 3) as the market representative price.

Classify against the same percentile bands:

| Market representative price | Classification |
| --------------------------- | -------------- |
| ≤ `price_p25_cents` | `:rare_cheap` |
| > p25 and ≤ p50 | `:below_median` |
| > p50 and ≤ p75 | `:above_median` |
| > `price_p75_cents` | `:expensive` |

### 8.3 Rules

- Compute the median of `flight.price_cents` across all ranked flights (not score-weighted, raw median).
- If `ranked_flights` is empty, return `nil`.
- If `snapshot.confidence == :low`, return `nil`.
- If `snapshot.price_distribution_present?` is false, return `nil`.

### 8.4 Output

```ruby
Search::Insights::PriceRarityInsight.new(
  classification:                    Symbol,    # :rare_cheap | :below_median | :above_median | :expensive
  market_representative_price_cents: Integer,   # median price used for classification
  confidence_level:                  Symbol     # :high, :medium, or :low — inherited from snapshot
)
```

---

## 9. Insight 4 — cheapest_comfort_window

### 9.1 Purpose

Surface the departure date range of flights that represent genuinely balanced options — flights that score well on both price and comfort simultaneously, not merely the cheapest or the most comfortable.

### 9.2 Algorithm

**Step 1** — Filter all `ranked_flights` where **both** of the following hold:

- `score_result.components[:price] >= BALANCED_SCORE_THRESHOLD`
- `score_result.components[:time_comfort] >= BALANCED_SCORE_THRESHOLD`

These are "balanced flights."

**Step 2** — If fewer than 2 balanced flights exist, return `nil`.

**Step 3** — From the balanced flights, find the earliest and latest `flight.departure_datetime` dates. The result spans those two dates, inclusive.

### 9.3 Rules

- `BALANCED_SCORE_THRESHOLD = 70` — a named constant; do not inline the value.
- Both the `:price` and `:time_comfort` component scores must independently meet the threshold. A flight scoring 90 on price and 65 on time_comfort does not qualify.
- If `snapshot.confidence == :low`, return `nil`.
- If fewer than 2 qualifying balanced flights exist, return `nil`.
- Date range is expressed as calendar dates.

### 9.4 Threshold rationale

Score 70 sits between the "above_median" band (score 50) and "below_median" band (score 80) in the scoring spec. Requiring ≥ 70 on both axes selects flights that are meaningfully good on both dimensions, not merely passable.

### 9.5 Output

```ruby
Search::Insights::DateRangeInsight.new(
  from_date:        Date,      # earliest departure date of a qualifying balanced flight
  to_date:          Date,      # latest departure date of a qualifying balanced flight
  average_score:    Float,     # average final score of qualifying balanced flights (0–100)
  flight_count:     Integer,   # number of qualifying balanced flights
  confidence_level: Symbol     # :high, :medium, or :low — inherited from snapshot
)
```

`best_time_to_travel` and `cheapest_comfort_window` share the `DateRangeInsight` value object. The two insights answer different questions — best cluster by composite score vs. balanced price-and-comfort flights — and may produce overlapping or non-overlapping date ranges.

---

## 10. Failure Semantics

`Search::Insights::Builder` returns `nil` when:

- `snapshot` is nil
- `ranked_flights` is nil (not merely empty)

These are **non-exceptional outcomes**.

An empty `ranked_flights` array is a valid input. The builder produces a `SearchInsights` object with nil date-range attributes and `wait_or_book.directive = :insufficient_data`.

Individual insight attributes return `nil` per their own rules (Sections 6–9) rather than raising. The `SearchInsights` container object is always fully constructed when the builder does not return nil.

---

## 11. Determinism

Given identical inputs:

- All insight outputs must be identical
- Tie-breaking rules are fully specified (no ambiguous ordering)
- No randomness is allowed
- No external state (time, env vars, I/O) may be accessed

---

## 12. Domain Objects

### Builder

```ruby
Search::Insights::Builder
```

Responsibilities:
- Accept `ranked_flights:`, `snapshot:`, `intent:`
- Guard against nil snapshot or nil ranked_flights
- Derive all four insight attributes
- Apply confidence gating per Section 5
- Return a `SearchInsights` or `nil`

Public interface:

```ruby
Search::Insights::Builder.call(
  ranked_flights:,
  snapshot:,
  intent:
)
# => Search::Insights::SearchInsights | nil
```

### SearchInsights

```ruby
Search::Insights::SearchInsights
```

- Holds all four insight attributes and `confidence_level`
- Enforces immutability (frozen)
- No business logic

### DateRangeInsight

```ruby
Search::Insights::DateRangeInsight
```

Shared value object used by both `best_time_to_travel` and `cheapest_comfort_window`.

Attributes: `from_date`, `to_date`, `average_score`, `flight_count`, `confidence_level`

### WaitOrBookInsight

```ruby
Search::Insights::WaitOrBookInsight
```

Attributes: `directive`, `price_band`, `top_flight_median_price_cents`, `confidence_level`

### PriceRarityInsight

```ruby
Search::Insights::PriceRarityInsight
```

Attributes: `classification`, `market_representative_price_cents`, `confidence_level`

All value objects:

- Use keyword arguments
- Are frozen on construction
- Contain no business logic

---

## 13. Integration with SearchExecution

`Search::SearchExecution` gains an `:insights` phase after `:ranking`, before `:completed`:

```
... → ranking → insights → completed
```

The resulting `SearchInsights` object is exposed as `search_execution.insights`.

When `snapshot` is nil (insufficient data from sampling), the insights phase is skipped and `search_execution.insights` remains nil — consistent with how scoring and explanation phases are skipped.

---

## 14. Explicit Non-Goals (MVP)

- Price prediction or trend analysis
- Historical comparison across multiple search runs
- User-personalized confidence thresholds
- Natural language generation (insights use symbolic keys; copy is resolved outside the domain)
- Monitoring or alerting on price changes
- Multi-destination comparison
- Seasonality detection
- Any fifth insight type not defined in PRODUCT_GUIDE.md Section 3
- Persisting `SearchInsights` to the database

---

## 15. Relationship to Other Domains

- **Ranking**: Insights consumes `ranked_flights` as its primary input. It never re-sorts or re-scores.
- **Analysis**: Insights inherits `confidence` and `volatility` from `AnalysisSnapshot`. It never re-derives these values.
- **Scoring**: Insights reads `score_result.components` to compute `cheapest_comfort_window`. It never modifies or recomputes scores.
- **Explanation**: Insights does not consume `FlightExplanation`. Per-flight explanations are a separate concern from cross-flight insights.
- **SearchExecution**: Orchestrates when Builder is invoked. Insights does not know about SearchExecution directly.
- **Presentation layer**: Consumes `SearchInsights` to render the insight summary block defined in PRD.md Section 7.1.

---

## 16. Implementation Instructions

When implementing insights:

- Follow this document strictly
- Do not invent insight types or directive values
- Do not persist results
- Do not re-derive confidence from raw samples
- Ask if unclear
