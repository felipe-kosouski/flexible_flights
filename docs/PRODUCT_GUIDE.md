# PRODUCT GUIDE — Flexible Flight Intelligence (MVP)

This document is the single source of truth for this project.
All code, architecture, and features must comply with it.

If there is ambiguity:
- Ask for clarification
- Do NOT invent features or assumptions

---

## 0. Product Identity (Immutable)

Product type:
- Decision intelligence SaaS for flexible flight travel

Primary question we answer:
- WHEN is the best time to travel?
- Should the user BOOK NOW or WAIT?

We do NOT optimize for:
- Booking completion
- Airline partnerships
- Lowest price today

---

## 1. Target User (MVP Scope)

### Included
- Digital nomads
- Flexible couples or families
- Price-aware travelers with date flexibility

### Excluded (for now)
- Fixed-date business travelers
- Luxury-first travelers
- Users expecting price guarantees

---

## 2. Paid MVP Contract (Hard Boundary)

### Paid unit
ONE **Smart Search**

A Smart Search represents:
- One destination
- One flexible date window
- One stay-length range
- One full analysis run

### What a Smart Search MUST deliver

1. Best Time to Travel
   - A concrete date range
   - Market-relative price context

2. Book vs Wait Recommendation
   - Deterministic
   - Confidence-gated
   - Time-bound

3. Cheapest Acceptable Options
   - Ranked flights
   - Comfort-aware
   - Explained in plain language

4. Explanations
   - Why this time
   - Why this price
   - Why this recommendation

### What a Smart Search MUST NOT deliver

- Price guarantees
- Continuous monitoring
- Booking or checkout
- Airline loyalty optimization
- Predictions without confidence

---

## 3. Core Domain Language (Canonical)

These names and meanings are fixed.

### SearchIntent
Represents user intent, not execution.

Fields:
- origin
- destination
- earliest_departure
- latest_return
- min_stay_days
- max_stay_days
- luggage_requirement
- max_stops

---

### FlightOption
Represents a concrete flight returned by a provider.

Fields:
- price
- air_time
- layover_time
- stops
- airlines
- luggage_included
- departure_time
- arrival_time

---

### Scores (All normalized 0–100)

Scores are explainable and deterministic.

- price_score
- comfort_score
- trip_fit_score
- market_score
- final_score

Scores must NEVER be hidden inside one another.

---

### Insights
Insights are derived artifacts, not raw data.

- best_time_to_travel
- wait_or_book
- price_rarity
- cheapest_comfort_window

Insights must carry:
- confidence_level (high | medium | low)

---

## 4. Scoring Rules (Strict)

### Comfort Score
Derived from:
- stops_score
- duration_score

Uses:
effective_duration = air_time + (layover_time × penalty)

Stops and duration are scored independently, then combined.

---

### Market Score
- Always route-relative
- Uses historical percentiles (p25, p50, p75)
- Must never compare across routes

Market score explains:
"Is this price good for THIS route at THIS time?"

---

### Trip Fit Score
- Measures alignment with trip intent
- Hard constraints are filtered, not scored
- Length fit is the dominant factor

---

## 5. Confidence System (Mandatory)

All insights are gated by confidence.

Confidence factors:
- Sample size
- Date coverage
- Price agreement (volatility)
- Data freshness

Rules:
- Lowest confidence factor wins
- Low confidence = no strong advice
- Never recommend "book" or "wait" with stale data

---

## 6. UX Principles (Non-Negotiable)

- Answers come before results
- Every recommendation must be explainable
- Use plain language, not jargon
- "We don’t know" is a valid outcome
- Paid value = insight, not more filters

---

## 7. Technical Architecture (MVP)

- Ruby on Rails monolith
- Hotwire + turbo for front end
- Tailwind Css
- PostgreSQL
- Background jobs for sampling and analysis
- Domain logic in plain Ruby objects (POROs)
- ActiveRecord models store facts, not decisions

No microservices.
No premature optimization.

---

## 8. Non-Goals (Explicit)

Do NOT implement:
- Flight booking
- Subscriptions (yet)
- Alerts (yet)
- User preference learning
- ML-based price prediction

---

## 9. Cursor Operating Rules

When generating code:
- Follow this document strictly
- Prefer explicit, readable logic
- Avoid hidden magic or abstraction layers
- Ask questions when unsure
- MVP scope > elegance

Cursor should behave like a careful junior engineer, not a product designer.