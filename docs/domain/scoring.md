# 📄 Domain Spec — Scoring & Ranking (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md — Smart Search Execution
- Domain Spec — Analysis & Market Stats

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

Scoring is responsible for ranking flight options in a way that reflects:

- Price attractiveness
- Travel comfort
- Trip fit for flexible travelers

Scoring produces relative ordering, not absolute truth.

Scoring does not:

- Predict prices
- Generate booking advice
- Persist results
- Override confidence rules

---

## 2. Inputs

Scoring receives:

- A list of flight_samples
- One analysis_snapshot

Each flight sample provides:

- Price
- Stops
- Duration
- Airlines
- Luggage inclusion
- Dates

Analysis snapshot provides:

- Price percentiles
- Route median duration
- Volatility
- Confidence level

---

## 3. Output

For each flight sample, scoring produces:

- final_score (float, 0–100)
- Per-dimension component scores (for explainability)

Scores are:

- Computed on demand
- Not persisted
- Used only for sorting and explanation

---

## 4. Scoring Dimensions (MVP)

Final score is a weighted combination of three dimensions:

| Dimension             | Weight |
|-----------------------|--------|
| Price Score           | 45%    |
| Time & Comfort Score  | 35%    |
| Trip Fit Score        | 20%    |

Weights are constants in MVP.

---

## 5. Dimension 1 — Price Score

### 5.1 Purpose

Measure how attractive a flight's price is relative to the market, not in absolute terms.

---

### 5.2 Inputs

- Flight price_cents
- Market percentiles (p25, p50, p75)

---

### 5.3 Price Positioning

Define price band:

- ≤ p25 → cheap
- p25–p50 → below_median
- p50–p75 → above_median
- ≥ p75 → expensive

---

### 5.4 Price Score Mapping

| Band         | Score |
|--------------|-------|
| cheap        | 100   |
| below_median | 80    |
| above_median | 50    |
| expensive    | 20    |

---

### 5.5 Notes

- No smoothing in MVP
- No airline-specific normalization
- Extreme outliers are scored normally

---

## 6. Dimension 2 — Time & Comfort Score

This dimension balances convenience and fatigue.

---

### 6.1 Subcomponents

Time & Comfort Score is composed of:

| Component       | Weight |
|-----------------|--------|
| Stops Score     | 60%    |
| Duration Score  | 40%    |

---

### 6.2 Stops Score

Stops score reflects itinerary simplicity.

| Stops | Score |
|-------|-------|
| 0     | 100   |
| 1     | 80    |
| 2     | 50    |
| ≥3    | 20    |

Max stops allowed by SearchIntent are enforced earlier.

---

### 6.3 Duration Score

Duration score is relative, not absolute.

**Step 1 — Effective Duration**

```
effective_duration = air_time_minutes +(layover_time_minutes * layover_penalty)
```

Where:

- layover_penalty = 1.3

**Step 2 — Relative Duration**

```
relative_duration = effective_duration / route_median_duration
```

**Step 3 — Duration Score Mapping**

| Relative Duration | Score |
|-------------------|-------|
| ≤ 0.9             | 100   |
| 0.9~1.1           | 80    |
| 1.1~1.3           | 50    |
| > 1.3             | 20    |

---

### 6.4 Final Time & Comfort Score

```
time_comfort_score = (stops_score × 0.6) + (duration_score × 0.4)
```

---

## 7. Dimension 3 — Trip Fit Score

### 7.1 Purpose

Trip Fit evaluates how well the flight aligns with flexible, long-stay travel.

This is intentionally simple in MVP.

---

### 7.2 Inputs

- Luggage inclusion
- Arrival & departure timing
- Stay length alignment

---

### 7.3 Subcomponents

| Factor                        | Score Impact |
|-------------------------------|--------------|
| Luggage included              | +20          |
| Reasonable arrival time       | +10          |
| Stay length near midpoint     | +10          |

Max Trip Fit Score: 40

---

### 7.4 Normalization

Trip Fit Score is normalized to 0–100.

---

## 8. Final Score Calculation

```
final_score = (price_score × 0.45) + (time_comfort_score × 0.35) + (trip_fit_score × 0.20)
```

Final scores are capped between 0 and 100.

---

## 9. Confidence Interaction

Confidence does not change scores.

Confidence affects:

- How results are labeled
- Whether strong recommendations are shown

Low confidence → neutral language only.

---

## 10. Sorting Rules

Flights are sorted by:

1. final_score DESC
2. price_cents ASC (tie-breaker)
3. stops ASC

---

## 11. What Scoring Must NOT Do

- 🚫 Persist scores
- 🚫 Filter out flights
- 🚫 Generate booking advice
- 🚫 Override confidence
- 🚫 Mutate data

Scoring ranks only.

---

## 12. Determinism

Given the same inputs:

- Scores must be identical
- No randomness is allowed

---

## 13. Domain Objects (To Be Implemented)

Scoring logic will live in:

```
Search::Scoring::PriceScore
Search::Scoring::TimeComfortScore
Search::Scoring::TripFitScore
Search::Scoring::FinalScore
```

Each object:

- Accepts plain Ruby input
- Returns numeric scores
- Has no Rails dependencies

---

## 14. Future (Explicitly Out of Scope)

- Personalized weights
- Learning-based ranking
- Airline preferences
- User profile adjustments

---

## 15. Cursor Instruction

When implementing scoring logic:

- Follow this document strictly
- Do not invent new factors
- Do not persist results
- Ask if unclear

---

End of document.
