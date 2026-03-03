# 📄 PRD.md — Smart Search Execution (MVP)

**Status:** Active  
**Owner:** Product  
**Governing document:** PRODUCT_GUIDE.md  
If conflicts arise, PRODUCT_GUIDE.md prevails.

---

## 1. Objective

Deliver a complete, end-to-end execution of a Smart Search, producing:

- Market-aware insights about when to travel
- A ranked list of flight options
- Confidence-gated recommendations

This PRD defines one vertical slice and nothing more.

---

## 2. In Scope

This PRD includes:

- Creating a SearchIntent
- Executing a SearchRun
- Sampling flights across flexible dates
- Analyzing market data
- Rendering insights and ranked options

---

## 3. Out of Scope

This PRD explicitly excludes:

- Payments
- User onboarding flows
- Alerts or monitoring
- Bookings
- Emails or notifications
- Subscriptions
- Historical price tracking

---

## 4. Entry Point

### User Action

User submits a Smart Search with:

- Origin airport
- Destination airport
- Earliest departure date
- Latest return date
- Minimum stay (days)
- Maximum stay (days)
- Luggage requirement
- Maximum stops

---

## 5. Core Entities

- SearchIntent — Immutable user input
- SearchRun — One execution of a SearchIntent
- FlightSample — Raw flight data
- AnalysisSnapshot — Derived market aggregates

---

## 6. SearchRun Lifecycle

### States

```
pending → sampling → analyzing → completed
                      ↘ failed
```

### State: pending

- SearchIntent exists
- SearchRun created
- Awaiting execution

### State: sampling

**Responsibilities**

- Generate date combinations
- Call flight providers
- Persist raw flight samples

**Rules**

- No scoring
- No ranking
- Partial results acceptable

---

### State: analyzing

**Responsibilities**

- Compute market statistics
- Compute volatility
- Compute confidence level
- Persist analysis snapshot

---

### State: completed

**Responsibilities**

- Expose results to user
- No further writes

---

### State: failed

**Responsibilities**

- Capture error reason
- Expose user-friendly failure state

---

## 7. User-Visible Output

### 7.1 Insight Summary

Must display:

- Best time to travel (date range)
- Book or wait recommendation
- Confidence level
- One-sentence explanation

---

### 7.2 Flight Options

Each option must show:

- Price
- Airlines
- Stops
- Total duration
- Luggage inclusion
- Reason for ranking

Sorted by final score (computed at read time).

---

### 7.3 Market Context

Show:

- Route median price
- Price percentile classification
- Volatility indication

---

## 8. Scoring & Insights Rules

- Scores are computed dynamically
- Scores are not persisted
- Strong recommendations require medium or high confidence
- Low confidence suppresses directive language

---

## 9. Confidence Rules

Confidence depends on:

- Sample size
- Date coverage
- Price volatility
- Data freshness

Lowest factor dominates.

---

## 10. UX Constraints

- Results render only after SearchRun completion
- No partial or streaming results
- Insight summary appears above flight list
- Minimal loading indicators only

---

## 11. Error Handling

- System errors mark SearchRun as failed
- Insufficient data yields low confidence, not failure
- User-visible messaging must be neutral and factual

---

## 12. Acceptance Criteria

This PRD is complete when:

- A Smart Search can be executed end-to-end
- Flight samples are collected
- Analysis snapshot is persisted
- Results page renders insights and flights
- Confidence gates recommendations
- No out-of-scope features are implemented

---

## 13. Open Questions (Allowed)

The following may be decided during implementation:

- Minimum viable sample size
- Volatility calculation method
- Sampling density heuristics

Any other decision requires updating PRODUCT_GUIDE.md.

---

## 14. Implementation Guidance

- Domain logic lives outside Rails models
- Jobs orchestrate, domain objects decide
- No callbacks for execution triggers
- Explicit state transitions only

---

## 15. AI Agent Usage Instruction

When implementing this PRD:

- Follow PRODUCT_GUIDE.md
- Follow this PRD strictly
- Do not invent features
- Ask before assuming behavior
