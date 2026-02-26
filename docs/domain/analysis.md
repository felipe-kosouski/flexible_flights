# 📄 Domain Spec — Analysis Snapshot (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md — Smart Search Execution
- Architecture.md
- Scoring Domain Spec

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

Analysis derives **market context** from sampled flight data.

It exists to answer questions such as:
- “Is this price cheap or expensive for this route?”
- “What is a typical duration?”
- “How reliable is this comparison?”

Analysis produces **facts**, not recommendations.

---

## 2. Responsibilities

Analysis MUST:

- Aggregate statistics from flight samples
- Produce a single immutable AnalysisSnapshot
- Be deterministic and explainable
- Be reusable by scoring and presentation layers

Analysis MUST NOT:

- Rank or score flights
- Filter results
- Persist data
- Perform I/O
- Depend on Rails or ActiveRecord
- Know about SearchRun orchestration

---

## 3. Inputs

Analysis receives:

- A collection of FlightSample domain objects

Each sample may expose:
- price_cents
- air_time_minutes
- layover_time_minutes
- stops

Invalid or incomplete samples may be ignored.

---

## 4. Output — AnalysisSnapshot

Analysis produces **one** snapshot object: 
```
Search::Models::AnalysisSnapshot
```

### Snapshot Attributes (MVP)

- price_p25_cents
- price_p50_cents
- price_p75_cents
- route_median_duration_minutes
- sample_count
- volatility (:low, :medium, :high)
- confidence (:low, :medium, :high)

The snapshot is:
- Immutable
- Serializable
- Passed into scoring components

---

## 5. Effective Duration Definition

Effective duration is defined as:

```
effective_duration_minutes = air_time_minutes + (layover_time_minutes × layover_penalty)
```

Where:
- layover_penalty = 1.3 (MVP constant)

This definition must be consistent with TimeComfortScore.

---

## 6. Price Statistics

### 6.1 Price Set Rules

- Use price_cents
- Ignore missing or zero prices
- Sort prices ascending
- No currency normalization occurs here

---

### 6.2 Percentiles

Compute:
- 25th percentile (p25)
- 50th percentile (median)
- 75th percentile (p75)

Rules:
- Deterministic, rank-based selection
- No interpolation
- Works with small sample sizes

---

## 7. Duration Statistics

- Compute effective duration per valid sample
- Use the median effective duration
- Ignore samples missing duration data

---

## 8. Volatility (MVP)

Volatility reflects **price dispersion**, not price level.

Calculation:
```
spread_ratio = (p75 - p25) / p50
```

Mapping:

| Spread Ratio | Volatility |
|-------------|------------|
| ≤ 0.20 | :low |
| 0.20–0.40 | :medium |
| > 0.40 | :high |

---

## 9. Confidence Level (MVP)

Confidence reflects **data reliability**, not advice.

Rules:

| Condition | Confidence |
|----------|------------|
| sample_count < 10 | :low |
| volatility == :high | :low |
| sample_count ≥ 20 AND volatility == :low | :high |
| otherwise | :medium |

Confidence does not affect scoring weights directly.

---

## 10. Failure Semantics

Analysis returns `nil` when:
- No valid prices exist
- No valid durations exist
- Sample list is empty

These are **non-exceptional outcomes**.

---

## 11. Determinism

Given the same inputs:
- Snapshot results must be identical
- No randomness is allowed

---

## 12. Domain Objects

### Snapshot Builder
```
Search::Analysis::SnapshotBuilder
```

- Accepts flight samples
- Filters invalid data
- Computes snapshot
- Returns AnalysisSnapshot or nil

---

### Snapshot Model
```
Search::Models::AnalysisSnapshot
```

- Holds computed values only
- Enforces immutability
- No business logic

---

## 13. Explicit Non-Goals (MVP)

- Seasonality
- Trends
- Airline normalization
- Historical comparisons
- ML or learning

---

End of document.