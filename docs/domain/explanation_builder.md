# Domain Spec — Explanation Builder (MVP)

**Governing documents:**

- [PRODUCT_GUIDE.md](../PRODUCT_GUIDE.md)
- [PRD.md](../PRD.md) — Smart Search Execution
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- Domain Spec — [Scoring](../domain/scoring.md)
- Domain Spec — [Analysis](../domain/analysis.md)
- Domain Spec — [Explanation](explanation.md)

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

The Explanation Builder is responsible for **deriving a deterministic, structured explanation** for a single flight result.

It transforms finalized domain outputs into an **explainable narrative structure** suitable for presentation layers.

It exists to answer:
- “Why did this flight receive this score?”
- “Which factors mattered most?”
- “What tradeoffs were involved?”

---

## 2. Responsibilities

The Explanation Builder MUST:

- Accept finalized scoring and analysis inputs
- Build exactly one FlightExplanation per flight
- Decompose the final score into explicit components
- Identify meaningful tradeoffs
- Produce deterministic, reproducible output

The Explanation Builder MUST NOT:

- Modify or recompute scores
- Perform aggregation across flights
- Persist data
- Perform I/O
- Depend on Rails or ActiveRecord
- Access providers, APIs, or UI concerns

---

## 3. Inputs

The Builder receives:

- FlightSample
- SearchIntent
- AnalysisSnapshot
- FinalScore (including component scores)

All inputs are assumed to be:
- Immutable
- Internally consistent
- Produced by upstream domains

---

## 4. Output — FlightExplanation

The Builder produces:

```ruby
Search::Explanation::FlightExplanation
```

The output:
- Represents one flight only
- Is immutable
- Is serializable
- Contains no business logic

---

## 5. Builder Interface (MVP)

The Builder exposes a single public method:

```ruby
Search::Explanation::Builder.call(
  flight:,
  intent:,
  snapshot:,
  score_result:
)
```

Where `score_result` is a `Search::Scoring::ScoreResult` containing both the final score value and per-dimension component scores.

Rules:
- Returns a FlightExplanation or nil
- Does not raise domain exceptions for missing data

---

## 6. Score Breakdown Construction

The Builder MUST construct `score_breakdown` from FinalScore.

### 6.1 Breakdown Entries

Each entry MUST include:
- dimension
- raw_score
- normalized_score
- weight
- weighted_contribution

Rules:
- Dimensions must match scoring components exactly
- Ordering must be deterministic
- No inferred or hidden adjustments

---

## 7. Summary Construction (MVP)

The Builder constructs a short, templated summary.

Rules:
- Summary must be derived solely from score breakdown and tradeoffs
- Uses predefined phrasing keys
- No free-form or generated language
- No personalization

Example structure:

```ruby
“This flight scored well due to %{strengths}, despite %{weaknesses}.”
```

Strengths and weaknesses are selected deterministically.

---

## 8. Thresholds and Constants

### 8.1 MATERIALITY_THRESHOLD (0.15)

A dimension must deviate more than 15% from the market baseline to be considered meaningfully different. This threshold governs:

- **Tradeoff eligibility**: only dimensions that cross this threshold qualify as a "gain" (deviation < -0.15) or "sacrifice" (deviation > +0.15).
- **Baseline position tagging**: each score breakdown entry is tagged `:better`, `:worse`, or `:neutral` based on whether the deviation crosses this threshold.

Without this threshold, near-baseline flights would produce noisy explanations.

### 8.2 STRONG_DEVIATION_THRESHOLD (0.35)

Determines tradeoff severity once a tradeoff has been detected:

| Condition | Severity |
| --- | --- |
| Both dimensions deviate >= 35% from baseline | `:high` |
| One dimension deviates >= 35%, the other does not | `:medium` |
| Neither crosses 35% (but both crossed 15%) | `:low` |

### 8.3 LAYOVER_PENALTY (1.3)

Layover time is inflated by 30% when computing effective travel duration for baseline comparisons:

```
effective_duration = air_time_minutes + (layover_time_minutes * 1.3)
```

This reflects that layover time is subjectively worse than flying time.

This constant is intentionally kept in sync with `TimeComfortScore::LAYOVER_PENALTY`. Both must use the same value to ensure the Builder's baseline comparisons agree with scoring's duration calculations.

---

## 9. Tradeoff Detection

### 9.1 Tradeoff Eligibility

A tradeoff exists when:
- One dimension deviates below -MATERIALITY_THRESHOLD (a gain)
- Another dimension deviates above +MATERIALITY_THRESHOLD (a sacrifice)
- Both dimensions have a recognized tradeoff key (e.g. price vs time_comfort)

Baseline definitions come from AnalysisSnapshot:
- Price baseline: median price (p50)
- Duration baseline: median effective duration

### 9.2 Tradeoff Severity

See STRONG_DEVIATION_THRESHOLD rules in Section 8.2.

Severity rules must be deterministic and explicit.

### 9.3 Tradeoff Output

Each detected tradeoff MUST include:
- gained_dimension
- sacrificed_dimension
- severity
- explanation_key

The Builder must not generate human-readable text directly.

---

## 10. Baseline Interpretation

The Builder computes baseline deviations as:

```
price_deviation = (flight.price_cents - snapshot.price_p50_cents) / snapshot.price_p50_cents
duration_deviation = (effective_duration - snapshot.route_median_duration_minutes) / snapshot.route_median_duration_minutes
```

Negative deviation = better than baseline. Positive deviation = worse than baseline.

The Builder MAY rely on:
- Price baseline (median price)
- Duration baseline (median effective duration)

The Builder MUST NOT:
- Recompute baselines from raw samples
- Perform statistical calculations

Baselines originate exclusively from AnalysisSnapshot.

---

## 10. Failure Semantics

The Builder returns `nil` when:
- FinalScore is missing
- Required component scores are missing
- Inputs are structurally invalid

These are **non-exceptional outcomes**.

---

## 11. Determinism

Given the same inputs:
- Builder output must be identical
- No randomness is allowed
- No external state may be accessed

---

## 12. Domain Objects

### Builder

```ruby
Search::Explanation::Builder
```

Responsibilities:
- Validate required inputs
- Assemble score breakdown
- Detect tradeoffs
- Build summary
- Return FlightExplanation

---

### Explanation Model

```ruby
Search::Explanation::FlightExplanation
```

- Holds explanation data only
- Enforces immutability
- No domain logic

---

## 13. Explicit Non-Goals (MVP)

- Natural language generation
- Multi-flight explanations
- Learning or adaptation
- Confidence estimation
- UI formatting
- Internationalization

---

## 14. Relationship to Other Domains

- **Scoring**: Source of truth for all numeric values
- **Analysis**: Provides baselines only
- **SearchRun**: Orchestrates when Builder is invoked
- **Insights (future)**: May consume explanations in aggregate

---