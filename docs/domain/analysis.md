# 📄 Domain Spec — Analysis & Market Stats (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md — Smart Search Execution

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

Analysis is responsible for deriving market context from sampled flight data so that:

- Prices can be interpreted (cheap vs normal vs expensive)
- Recommendations are confidence-aware
- Insights are explainable in plain language

Analysis does not:

- Rank flights
- Select "best" options
- Decide booking actions

It produces facts, not opinions.

---

## 2. Inputs

Analysis receives:

- A completed SearchRun
- A collection of flight_samples associated with the run

Each sample contains:

- Price
- Duration
- Stops
- Airlines
- Dates

---

## 3. Outputs

Analysis produces exactly one analysis_snapshot containing:

- Price percentiles
- Route median duration
- Volatility index
- Sample size
- Confidence level

No per-flight scores are persisted.

---

## 4. Pre-Conditions

Analysis may run if:

- At least 1 flight_sample exists

Analysis does not fail due to insufficient data.
Insufficient data is reflected in confidence, not errors.

---

## 5. Market Price Statistics

### 5.1 Price Set Definition

- Prices are taken from price_cents
- Currency normalization must already have occurred
- Invalid or zero prices must be ignored

---

### 5.2 Percentile Calculations

Compute:

- p25 — 25th percentile
- p50 — 50th percentile (median)
- p75 — 75th percentile

**Rules:**

- Percentiles are computed across all samples
- No date segmentation in MVP
- Use deterministic percentile logic

---

### 5.3 Interpretation Bands

Percentiles are used later to classify prices:

- ≤ p25 → cheap
- p25–p75 → normal
- ≥ p75 → expensive

Classification itself is not stored here.

---

## 6. Route Duration Statistics

### 6.1 Duration Definition

Effective duration is defined as:

```
effective_duration_minutes = air_time_minutes + (layover_time_minutes * layover_penalty)
```

Where:

- layover_penalty = 1.3 (MVP constant)

---

### 6.2 Route Median Duration

- Compute the median effective duration across all samples
- Store as route_median_duration_minutes

This value is used later for comfort scoring and explainability.

---

## 7. Volatility Index

### 7.1 Purpose

Volatility measures price dispersion, not price level.

---

### 7.2 Calculation (MVP)

Volatility index is defined as:

```
volatility_index = (p75 - p25) / p50
```

**Rules:**

- If p50 == 0 → volatility_index = 0
- Values typically range from 0.1 to 0.6
- Higher = less stable market

---

## 8. Sample Size

- sample_size = number of valid flight samples
- Stored explicitly for explainability

---

## 9. Confidence Level

Analysis computes inputs to confidence, not final advice.

Confidence is categorized as:

- low
- medium
- high

---

### 9.1 Confidence Factors

Factors considered:

| Factor         | Measurement              |
|----------------|--------------------------|
| Sample size    | Count of samples         |
| Date coverage  | Derived from sampling    |
| Volatility     | volatility_index         |
| Freshness      | search_run.data_fresh_until |

---

### 9.2 MVP Confidence Rules

Use the lowest dominating factor.

Suggested thresholds (MVP):

- **Low confidence** if any:
  - sample_size < 15
  - volatility_index > 0.5
  - data freshness expired
- **High confidence** if all:
  - sample_size ≥ 30
  - volatility_index < 0.3
  - data is fresh
- **Medium confidence** otherwise

Thresholds may be adjusted later.

---

## 10. What Analysis Must NOT Do

- 🚫 Rank flights
- 🚫 Score flights
- 🚫 Generate recommendations
- 🚫 Produce user-facing language
- 🚫 Mutate flight_samples

Analysis produces neutral aggregates only.

---

## 11. Failure Handling

Analysis fails only if:

- System-level error occurs

If analysis fails:

- SearchRun is marked failed
- No partial snapshot is saved

---

## 12. Determinism

Given the same flight samples:

- Analysis results must be deterministic
- No randomness is allowed

This is critical for debugging and trust.

---

## 13. Domain Objects (To Be Implemented)

Analysis logic will live in:

```
Search::Analysis::MarketStats
Search::Analysis::DurationStats
Search::Analysis::Volatility
Confidence::Evaluator
```

Each object:

- Accepts plain Ruby data
- Returns plain Ruby values
- Has no Rails dependencies

---

## 14. Future (Explicitly Out of Scope)

- Time-series price trends
- Seasonal modeling
- Airline-specific normalization
- Historical comparisons

---

## 15. Cursor Instruction

When implementing analysis logic:

- Follow this document strictly
- Do not infer user intent
- Do not generate recommendations
- Ask if unclear

---

End of document.
