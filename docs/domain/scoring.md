# Domain Spec — Scoring & Ranking (MVP)

**Governing documents:**

- [PRODUCT_GUIDE.md](../PRODUCT_GUIDE.md)
- [PRD.md](../PRD.md) — Smart Search Execution
- Domain Spec — Analysis & Market Stats

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

Scoring is responsible for ranking flight options in a way that reflects:

- Price attractiveness relative to the market
- Travel comfort and fatigue
- Fitness for the intended type of trip

Scoring produces **relative ordering**, not absolute recommendations.

Scoring does **not**:

- Predict future prices
- Enforce hard constraints
- Generate booking advice
- Persist results
- Override confidence rules

---

## 2. Inputs

Scoring receives:

- A list of `flight_samples`
- One `analysis_snapshot`
- One `search_intent` (read-only)

### Flight sample fields

| Field               | Description          |
| ------------------- | -------------------- |
| `price_cents`       | Price in cents       |
| `stops`             | Number of stops      |
| `air_time_minutes`  | Air time             |
| `layover_time_minutes` | Layover time     |
| `airlines`          | Airline codes        |
| `luggage_included`  | Luggage flag         |
| `departure_datetime`| Departure timestamp  |
| `return_datetime`   | Return timestamp     |

### Analysis snapshot fields

| Field                         | Description            |
| ----------------------------- | ---------------------- |
| `price_p25_cents`             | 25th percentile price  |
| `price_p50_cents`             | Median price           |
| `price_p75_cents`             | 75th percentile price  |
| `route_median_duration_minutes` | Route median duration |
| `volatility_index`            | Volatility metric      |
| `confidence_level`            | Confidence level       |

### Search intent fields

| Field                | Description        |
| -------------------- | ------------------- |
| `min_stay_days`      | Minimum stay days   |
| `max_stay_days`      | Maximum stay days   |
| `luggage_requirement`| Luggage requirement |
| `max_stops`          | Maximum stops       |

---

## 3. Output

For each flight sample, scoring produces a `Search::Scoring::ScoreResult`:

- `value` (Float, 0–100) — the final weighted score
- `components` (Hash) — per-dimension component scores (Float, 0–100 each), keyed by dimension symbol

ScoreResult is:

- Immutable (frozen)
- Computed on demand
- Deterministic
- Not persisted
- Used for sorting, explanation, and ranking

---

## 4. Scoring Dimensions (MVP)

Final score is a weighted combination of three dimensions:

| Dimension            | Weight |
| -------------------- | ------ |
| Price Score          | 45%    |
| Time & Comfort Score  | 35%    |
| Trip Fit Score       | 20%    |

Weights are constants in MVP.

---

## 5. Dimension 1 — Price Score

### 5.1 Purpose

Measure how attractive a flight's price is **relative to the observed market**, not in absolute terms.

Inputs
	•	flight_sample
	•	price_cents
	•	analysis_snapshot
	•	price_p25_cents
	•	price_p50_cents
	•	price_p75_cents

Output
	•	A numeric score (Integer or Float is fine)
	•	Range: 0–100

### 5.2 Inputs

- `price_cents`
- `price_p25_cents`
- `price_p50_cents`
- `price_p75_cents`

### 5.3 Price banding

| Price position   | Definition   |
| ---------------- | ------------ |
| `cheap`          | ≤ p25        |
| `below_median`   | p25 – p50    |
| `above_median`   | p50 – p75    |
| `expensive`     | ≥ p75        |

### 5.4 Score mapping

| Band           | Score |
| -------------- | ----- |
| `cheap`        | 100   |
| `below_median` | 80    |
| `above_median` | 50    |
| `expensive`    | 20    |

### 5.5 Notes

- No smoothing in MVP
- No airline normalization
- Outliers are scored normally

---

## 6. Dimension 2 — Time & Comfort Score

This dimension balances simplicity and fatigue.

### 6.1 Subcomponents

| Component       | Weight |
| --------------- | ------ |
| Stops Score     | 60%    |
| Duration Score  | 40%    |

### 6.2 Stops score

| Stops | Score |
| ----- | ----- |
| 0     | 100   |
| 1     | 80    |
| 2     | 50    |
| ≥3    | 20    |

Hard `max_stops` enforcement occurs earlier.

### 6.3 Duration score

**Step 1 — Effective duration**

```
effective_duration = air_time_minutes + (layover_time_minutes × 1.3)
```

**Step 2 — Relative duration**

```
relative_duration = effective_duration / route_median_duration_minutes
```

**Step 3 — Score mapping**

| Relative duration | Score |
| ----------------- | ----- |
| ≤ 0.9             | 100   |
| 0.9 – 1.1         | 80    |
| 1.1 – 1.3         | 50    |
| > 1.3             | 20    |

### 6.4 Final time & comfort score

```
time_comfort_score = (stops_score × 0.6) + (duration_score × 0.4)
```

---

## 7. Dimension 3 — Trip Fit Score

### 7.1 What trip fit is (and is not)

**Trip Fit is:**

- A measure of how well a flight matches the **intent of the trip**
- A guardrail against useless results
- A light personalization layer

**Trip Fit is not:**

- Preference-learning AI
- A replacement for hard filters
- A place to be clever

Hard constraints always win. Trip Fit applies **only after constraints pass**.

### 7.2 Core components (MVP)

Trip Fit is composed of:

1. Trip Length Fit (most important)
2. Luggage Fit
3. Departure / Arrival Time Fit
4. Stay Pattern Fit (nomads only, bonus)

Each component returns a score between **0.0 and 1.0**.

### 7.3 Component 1 — Trip length fit

**Purpose:** Evaluate alignment between actual stay length and user intent.

**Definitions:**

```
L_min = min_stay_days
L_max = max_stay_days
L_mid = (L_min + L_max) / 2
```

**Scoring shape (non-linear):**

| Stay length position        | Fit      |
| --------------------------- | -------- |
| Exactly L_mid                | 1.0      |
| Within ±20% of range        | 0.9      |
| Near L_min or L_max         | 0.7      |
| Slightly outside (±2–3 days)| 0.4      |
| Far outside                 | 0.0 (discard) |

### 7.4 Component 2 — Luggage fit (strict)

| Condition              | Luggage included | Luggage not included |
| ---------------------- | ---------------- | -------------------- |
| Luggage required        | 1.0              | 0.0 (discard)         |
| Luggage optional        | 1.0              | 0.8                  |

Luggage cost is never hidden inside price.

### 7.5 Component 3 — Departure / arrival time fit

**Reasonable windows (defaults):**

- Departure: 06:00–22:00
- Arrival: 07:00–23:00

**Scoring:**

| Situation                  | Fit   |
| -------------------------- | ----- |
| Both within window         | 1.0   |
| One slightly outside       | 0.85  |
| Red-eye or very late arrival | 0.6 |
| Multiple bad timings       | 0.4   |

### 7.6 Component 4 — Stay pattern fit (nomads only)

Soft bonus only.

**Examples:**

- Monthly-aligned stays (30 / 60 / 90 days)
- Return near month end

**Scoring:**

- Pattern match → +0.1
- No match → neutral

Never a penalty.

### 7.7 Trip fit combination

```
raw = (length_fit × 0.5) + (luggage_fit × 0.3) + (time_fit × 0.2)
raw += stay_pattern_bonus  # if applicable
trip_fit_score = raw × 100
```

Components are 0.0–1.0 internally. The combined result is scaled to 0–100 before entering the final score formula.

---

## 8. Final score calculation

```
final_score = (price_score × 0.45) + (time_comfort_score × 0.35) + (trip_fit_score × 0.20)
```

Scores are capped between 0 and 100.

---

## 9. Confidence interaction

Confidence does not modify scores.

Confidence affects:

- Messaging tone
- Strength of recommendations

Low confidence → neutral language only.

---

## 10. Sorting rules

Flights are sorted by:

1. `final_score` DESC
2. `price_cents` ASC
3. `stops` ASC

---

## 11. What scoring must NOT do

- Persist scores
- Filter flights
- Enforce constraints
- Generate advice
- Mutate input data

---

## 12. Determinism guarantee

Given identical inputs:

- Scores must be identical
- Ordering must be identical
- No randomness allowed

---

## 13. Domain objects

| Object                              | Purpose                          |
| ----------------------------------- | -------------------------------- |
| `Search::Scoring::PriceScore`       | Price dimension                  |
| `Search::Scoring::TimeComfortScore` | Time & comfort                   |
| `Search::Scoring::TripFit`          | Trip fit dimension               |
| `Search::Scoring::FinalScore`       | Final weighted score computation |
| `Search::Scoring::ScoreResult`      | Immutable result value object    |

All objects:

- Plain Ruby
- No Rails dependencies
- No persistence

---

## 14. Future (explicitly out of scope)

- Personalized weights
- Learning-based ranking
- Airline preferences
- User profile modeling

---

## 15. Cursor instruction

When implementing scoring:

- Follow this document strictly
- Do not invent factors
- Do not persist results
- Ask if unclear
