# Domain Spec — FlightExplanation (MVP)

**Governing documents:**

- [PRODUCT_GUIDE.md](../PRODUCT_GUIDE.md)
- [PRD.md](../PRD.md) — Search Result Transparency
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- Domain Spec — [Scoring](../domain/scoring.md)
- Domain Spec — [Analysis](../domain/analysis.md)
- Domain Spec — [Explanation Builder](explanation_builder.md)

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

FlightExplanation represents a **structured, deterministic explanation** of *why a specific flight received its final score*.

It exists to:
- Make scoring transparent
- Support UI presentation
- Enable trust and inspection

FlightExplanation explains **results**, not decisions.

---

## 2. Responsibilities

FlightExplanation MUST:

- Represent a single flight’s explanation
- Decompose the FinalScore into understandable parts
- Reference analysis baselines explicitly
- Be immutable and serializable
- Be safe to expose to presentation layers

FlightExplanation MUST NOT:

- Perform scoring
- Perform analysis
- Fetch data
- Mutate domain objects
- Depend on Rails, I18n, or persistence
- Contain UI copy or formatting logic

---

## 3. Identity & Scope

- One FlightExplanation corresponds to **exactly one FlightSample**
- It is always contextual to **one SearchRun**
- It does not compare multiple flights directly

---

## 4. Inputs (Conceptual)

FlightExplanation is constructed from:

- FlightSample
- SearchIntent
- AnalysisSnapshot
- FinalScore (including component scores)

These inputs are **not stored verbatim**, only their derived values.

---

## 5. Core Attributes (MVP)

```ruby
Search::Models::FlightExplanation
```

### 5.1 Required Attributes

| Attribute       | Type                         | Description                    |
| --------------- | --------------------------- | ----------------------------- |
| flight_id      | String                       | Stable identifier for the flight sample     |
| final_score    | Float                        | Final normalized score (0–100)            |
| score_breakdown | Array&lt;ScoreComponentExplanation&gt; | Decomposition of score              |
| summary       | ExplanationSummary           | High-level explanation                 |
| tradeoffs     | Array&lt;TradeoffExplanation&gt;   | Detected tradeoffs (may be empty)     |
| baselines    | ExplanationBaselines        | Market/reference values             |
| metadata     | Hash                       | Non-semantic context                |

---

## 6. Score Breakdown

### 6.1 ScoreComponentExplanation

Each entry in `score_breakdown` MUST include:

| Attribute              | Type   | Description                    |
| ---------------------- | ------ | ----------------------------- |
| dimension           | Symbol | e.g. :price, :time_comfort, :trip_fit |
| raw_score          | Numeric | Dimension-specific raw value     |
| normalized_score   | Float  | Normalized 0–100             |
| weight            | Float  | Weight applied to this dimension |
| weighted_contribution | Float  | normalized_score × weight      |
| relative_to_baseline | Symbol | :better, :worse, :neutral   |

Rules:
- One entry per scoring dimension
- Ordering is deterministic
- Dimensions map 1:1 to scoring components

---

## 7. Summary

### 7.1 ExplanationSummary

The summary provides a **concise, structured explanation**.

| Attribute         | Type           | Description                          |
| ----------------- | -------------- | ------------------------------------ |
| primary_factors  | Array&lt;Symbol&gt; | Dominant positive dimensions       |
| secondary_factors | Array&lt;Symbol&gt; | Supporting dimensions          |
| explanation_keys | Array&lt;Symbol&gt; | Semantic explanation tokens       |

Rules:
- No free text
- All values must be derivable from score_breakdown and tradeoffs
- Keys are resolved to copy outside the domain layer

---

## 8. Tradeoffs

### 8.1 TradeoffExplanation

Each tradeoff represents a **meaningful compromise**.

| Attribute            | Type   | Description              |
| -------------------- | ------ | ------------------------ |
| gained_dimension    | Symbol | Dimension that scored well |
| sacrificed_dimension | Symbol | Dimension that scored poorly |
| severity          | Symbol | :low, :medium, :high   |
| explanation_key    | Symbol | Semantic identifier     |

Rules:
- Tradeoffs are optional
- Multiple tradeoffs may exist
- Severity is deterministic

---

## 9. Baselines

### 9.1 ExplanationBaselines

Baselines contextualize performance.

| Attribute                 | Type     | Description           |
| ------------------------- | -------- | --------------------- |
| price_median_cents      | Integer? | Market median price    |
| duration_median_minutes | Integer? | Market median duration |
| volatility            | Symbol?  | :low, :medium, :high |
| confidence           | Symbol?  | :low, :medium, :high |

Rules:
- Values originate exclusively from AnalysisSnapshot
- Missing values are allowed
- No computation occurs here

---

## 10. Metadata

`metadata` is a shallow hash for:

- version
- builder_version
- timestamps (optional, injected externally)

Rules:
- Must not affect explanation semantics
- Must not be required for interpretation

---

## 11. Immutability

FlightExplanation MUST be immutable:

- Attributes are frozen
- Nested structures are frozen
- Any mutation attempt should raise or fail silently

---

## 12. Failure Semantics

FlightExplanation is **never partially valid**.

If required attributes cannot be produced:

- Builder returns `nil`
- No exception is raised

---

## 13. Determinism

Given identical inputs:
- All attributes must be identical
- Ordering must be stable
- No randomness, time, or external state allowed

---

## 14. Serialization

FlightExplanation MUST be safely serializable to:

- Hash
- JSON

Serialization must preserve:
- Structure
- Ordering
- Semantic identifiers

---

## 15. Explicit Non-Goals (MVP)

- Natural language generation
- UI formatting
- Multi-flight aggregation
- Confidence explanations
- Personalization
- ML-based reasoning

---

## 16. Domain Placement

```ruby
Search::Models::FlightExplanation
```

Constructed exclusively by:

```ruby
Search::Explanation::Builder
```

---