# 📄 Domain Spec — Search Sampling (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD — Smart Search Execution

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

Sampling is responsible for collecting a representative set of flight options across a flexible date window, while:

- Controlling API costs
- Avoiding bias toward any single date
- Producing enough data for confidence-aware insights

Sampling does not:

- Decide what is "good"
- Rank flights
- Generate recommendations

---

## 2. Inputs

Sampling receives a SearchIntent with:

- earliest_departure : Date
- latest_return : Date
- min_stay_days : Integer
- max_stay_days : Integer
- max_stops : Integer
- luggage_requirement : enum
- origin_airport : String
- destination_airport : String

---

## 3. Outputs

Sampling produces:

- A list of flight_samples
- Each sample represents one priced itinerary
- Samples may vary by:
  - Departure date
  - Return date
  - Airline
  - Stops
  - Duration

Sampling does not guarantee:

- Full coverage
- The absolute cheapest option

It guarantees representative coverage.

---

## 4. Core Concept — Date Grid

### 4.1 Definitions

- **Departure Window**  
  From earliest_departure to latest_return - min_stay_days
- **Stay Length Range**  
  From min_stay_days to max_stay_days
- **Return Date**  
  return_date = departure_date + stay_length

---

### 4.2 Validity Rules

A (departure_date, return_date) pair is valid if:

- departure_date >= earliest_departure
- return_date <= latest_return
- stay_length ∈ [min_stay_days, max_stay_days]

Invalid pairs must never be sampled.

---

## 5. Sampling Strategy (MVP)

### 5.1 Sampling Density

Sampling must:

- Cover the entire departure window
- Avoid clustering around edges
- Avoid sampling every day (cost explosion)

**Rules:**

- Max departure samples: 12
- Evenly spaced across the window
- If window < 12 days → sample every day

---

### 5.2 Stay Length Sampling

For each sampled departure date:

- Sample up to 3 stay lengths
- Chosen as:
  - min_stay_days
  - midpoint of stay range
  - max_stay_days

If range size < 3 → sample all possible stays.

---

### 5.3 Maximum Combinations

**Hard cap:**

- Max total date combinations: 36

If exceeded:

- Reduce stay-length samples first
- Never reduce departure coverage below 6 dates

This rule is non-negotiable.

---

## 6. Provider Call Rules

### 6.1 Provider Abstraction

Sampling calls flight providers via:

```
Search::Sampling::ProviderAdapter
```

**Rules:**

- Providers return raw itineraries
- Provider-specific quirks are hidden
- Sampling never parses provider-specific fields directly

---

### 6.2 Stop Conditions

Sampling must stop when any of the following occurs:

- Max date combinations reached
- Provider rate limit reached
- Time budget exceeded (configurable)

Partial results are acceptable.

---

## 7. Sample Normalization

Each provider result must be normalized into:

- price_cents
- currency
- air_time_minutes
- layover_time_minutes
- stops
- airlines
- luggage_included
- departure_datetime
- return_datetime

If normalization fails:

- Drop the sample
- Log the error
- Continue sampling

---

## 8. Minimum Viable Sample Size

Sampling is considered successful if:

- At least 15 flight samples are collected

If fewer:

- Sampling still completes
- Confidence will later be low

Sampling never retries endlessly to "hit quota".

---

## 9. What Sampling Must NOT Do

- 🚫 Score flights
- 🚫 Rank flights
- 🚫 Filter "bad" flights (beyond hard constraints)
- 🚫 Infer user preferences
- 🚫 Write analysis or insights

Sampling is blind and neutral.

---

## 10. Failure Handling

Sampling fails if:

- No providers respond
- SearchIntent is invalid
- System-level error occurs

In failure:

- SearchRun is marked failed
- Error reason is recorded
- No retries beyond job policy

---

## 11. Determinism & Reproducibility

Given the same SearchIntent and provider responses:

- Sampling behavior must be deterministic
- Randomness is forbidden in MVP

This is critical for trust and debugging.

---

## 12. Future (Explicitly Out of Scope)

- Adaptive sampling
- Learning-based heuristics
- Historical price weighting
- Multi-origin searches

---

## 13. Domain Objects (To Be Implemented)

Sampling logic will live in:

```
Search::Sampling::DateGrid
Search::Sampling::StayLengthSelector
Search::Sampling::ProviderAdapter
Search::Sampling::Runner
```

Each object must:

- Do one thing
- Be unit-testable
- Have no Rails dependencies

---

## 14. Cursor Instruction (Important)

When implementing sampling logic:

- Follow this document strictly
- Do not invent rules
- Ask if unclear
- Prefer clarity over cleverness
