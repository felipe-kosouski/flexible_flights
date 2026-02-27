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

## 8. Tradeoff Detection

### 8.1 Tradeoff Eligibility

A tradeoff exists when:
- One dimension is materially above baseline
- Another dimension is materially below baseline
- Both dimensions materially affect final score

Baseline definitions come from AnalysisSnapshot.

---

### 8.2 Tradeoff Severity

Severity mapping (MVP):

| Condition                        | Severity  |
| -------------------------------- | --------- |
| Minor contribution imbalance    | `:low`    |
| Clear but acceptable compromise | `:medium` |
| Strong sacrifice for gain       | `:high`   |

Severity rules must be deterministic and explicit.

---

### 8.3 Tradeoff Output

Each detected tradeoff MUST include:
- gained_dimension
- sacrificed_dimension
- severity
- explanation_key

The Builder must not generate human-readable text directly.

---

## 9. Baseline Interpretation

The Builder MAY rely on:
- Price baseline (median price)
- Duration baseline (median effective duration)

The Builder MUST NOT:
- Recompute baselines
- Perform statistical calculations

Scoring components must expose baseline-relative context.

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