# Domain Spec — Explanation (MVP)

**Governing documents:**

- [PRODUCT_GUIDE.md](../PRODUCT_GUIDE.md)
- [PRD.md](../PRD.md) — Smart Search Execution
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- Domain Spec — [Scoring](../domain/scoring.md)
- Domain Spec — [Analysis](../domain/analysis.md)

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

Explanation derives **human-readable, structured reasoning** from scoring and analysis outputs.

It exists to answer questions such as:
- “Why did this flight rank higher than others?”
- “What factors contributed most to its score?”
- “What tradeoffs were made?”

Explanation produces **facts and rationale**, not persuasion or recommendations.

---

## 2. Responsibilities

Explanation MUST:

- Explain the outcome of scoring for a single flight
- Attribute score contributions to explicit dimensions
- Surface meaningful tradeoffs
- Be deterministic and reproducible
- Be reusable by presentation and insight layers

Explanation MUST NOT:

- Modify scores
- Rank flights
- Perform analysis or aggregation
- Persist data
- Perform I/O
- Depend on Rails or ActiveRecord
- Know about provider or UI concerns

---

## 3. Inputs

Explanation receives:

- A FlightSample domain object
- A SearchIntent domain object
- An AnalysisSnapshot
- A FinalScore result (including component scores)

All inputs are assumed to be **finalized and immutable**.

---

## 4. Output — FlightExplanation

Explanation produces **one explanation per flight**:

```ruby
Search::Explanation::FlightExplanation
```

The explanation is:
- Immutable
- Serializable
- Safe for presentation layers

---

## 5. Explanation Structure (MVP)

### 5.1 Core Attributes

A FlightExplanation MUST expose:

- flight (FlightSample reference)
- final_score
- summary
- score_breakdown
- tradeoffs

---

### 5.2 Summary

The summary is a short, deterministic explanation of the ranking outcome.

Rules:
- Must be derivable solely from inputs
- No natural language generation (templated phrasing only)
- No personalization

Example:

> "This flight scored well due to a low price and acceptable travel time, despite a longer layover."

---

## 6. Score Breakdown

Score breakdown explains **how the final score was composed**.

Each breakdown entry MUST include:
- dimension (e.g. :price, :time_comfort, :trip_fit)
- raw_score
- normalized_score
- weight
- weighted_contribution

Rules:
- Dimensions must match scoring components exactly
- Ordering is deterministic
- No hidden adjustments

---

## 7. Tradeoffs (MVP)

A tradeoff represents a **meaningful compromise** between dimensions.

### 7.1 Tradeoff Definition

A tradeoff exists when:
- One dimension deviates more than 15% below baseline (a gain)
- Another dimension deviates more than 15% above baseline (a sacrifice)
- Both dimensions have a recognized tradeoff pair

"Significantly" is defined by `MATERIALITY_THRESHOLD` (0.15). See [Explanation Builder](explanation_builder.md) Section 8 for full threshold definitions.

---

### 7.2 Tradeoff Attributes

Each tradeoff MUST include:
- gained_dimension
- sacrificed_dimension
- severity (:low, :medium, :high)
- explanation_key (symbolic, not free text)

Example:

```ruby
:gained_dimension => :price
:sacrificed_dimension => :time_comfort
:severity => :medium
:explanation_key => :cheap_but_longer
```

---

## 8. Baseline Definitions (MVP)

Baselines are derived from AnalysisSnapshot:

- Price baseline: median price (p50)
- Duration baseline: median effective duration (with layover inflated at 1.3x)

Deviation from baseline is computed as a ratio: `(actual - baseline) / baseline`.
Negative values mean better than the market; positive values mean worse.

The Builder classifies each dimension as:
- `:better` — deviation below -0.15
- `:neutral` — deviation between -0.15 and +0.15
- `:worse` — deviation above +0.15

Explanation must not recompute baselines from raw samples.

---

## 9. Failure Semantics

Explanation returns `nil` when:
- FinalScore is missing
- Required inputs are incomplete

These are **non-exceptional outcomes**.

---

## 10. Determinism

Given the same inputs:
- Explanation output must be identical
- No randomness is allowed
- No external state may be accessed

---

## 11. Domain Objects

### Explanation Builder

```ruby
Search::Explanation::Builder
```

Responsibilities:
- Accept finalized inputs
- Build a FlightExplanation
- Detect tradeoffs
- Assemble summary and breakdown

---

### Explanation Model

```ruby
Search::Explanation::FlightExplanation
```

- Holds explanation data only
- Enforces immutability
- No business logic

---

## 12. Explicit Non-Goals (MVP)

- Natural language generation
- Multi-flight explanations
- Confidence or trust scoring
- User personalization
- Cross-search comparisons
- Visualization concerns

---

## 13. Relationship to Other Domains

- **Scoring**: Explanation explains scoring output, never alters it
- **Analysis**: Explanation consumes analysis facts as baselines
- **Insights (future)**: May aggregate explanations across searches
- **Confidence (future)**: May evaluate explanation strength, not content

---