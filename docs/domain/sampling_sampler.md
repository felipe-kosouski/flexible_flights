# 📄 Domain Spec — Sampling Sampler (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md
- docs/domain/sampling.md
- docs/domain/sampling_candidate_selector.md

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

The Sampler is responsible for executing flight searches for a given set of date pairs and producing normalized flight_samples.

It is the only domain object allowed to interact with external flight APIs.

---

## 2. Responsibilities

The Sampler must:

- Iterate over selected (departure_date, return_date) pairs
- Execute flight search requests
- Normalize API responses into a canonical format
- Return raw flight samples for persistence

---

## 3. What the Sampler Is NOT

The Sampler does not:

- 🚫 Decide which date pairs to sample
- 🚫 Score flights
- 🚫 Rank results
- 🚫 Interpret prices
- 🚫 Persist data
- 🚫 Manage retries at job level

It is an executor + normalizer, nothing more.

---

## 4. Inputs

The Sampler is initialized with:

- **origin** (String) — airport or city code
- **destination** (String) — airport or city code
- **date_pairs** (Array<[Date, Date]>)
- **passengers** (Integer, default: 1)
- **cabin_class** (Symbol, default: :economy)

Optional (future):

- max_results_per_search

---

## 5. Output

The Sampler returns:

```
Array<flight_sample>
```

Each flight_sample is a plain Ruby hash or value object with normalized fields.

No persistence occurs here.

---

## 6. Flight Sample Schema (MVP)

Each flight sample must contain:

| Field              | Type    | Description              |
|--------------------|---------|---------------------------|
| departure_date     | Date    | Outbound date             |
| return_date        | Date    | Inbound date              |
| price_cents         | Integer | Total trip price          |
| currency           | String  | Normalized currency       |
| airline_codes      | Array   | Operating carriers        |
| stops_count        | Integer | Total stops               |
| air_time_minutes   | Integer | Total airborne time      |
| layover_time_minutes | Integer | Total layover time      |
| baggage_included   | Boolean | Cabin or checked          |
| raw_provider       | String  | API identifier            |

All fields are mandatory in MVP.

---

## 7. Execution Rules

### 7.1 Iteration

- Each date pair results in one API search
- Date pairs are processed sequentially (MVP)
- Parallelism is out of scope

---

### 7.2 Empty Results

If an API call returns:

- No flights
- Invalid response

Then:

- No samples are produced for that date pair
- Processing continues

This is not an error.

---

### 7.3 Partial Failures

If a single date pair fails:

- Sampler continues with remaining pairs
- Errors are surfaced to the caller (Runner)

Sampler does not retry by itself.

---

## 8. Normalization Rules

- Prices must be normalized to price_cents
- Currency must be consistent within a run
- Time units must be minutes
- Stops must be explicit

Provider-specific quirks must be hidden.

---

## 9. Determinism

Given:

- Same date pairs
- Same API responses

Sampler output must be deterministic.

**Ordering:**

- Preserve input date pair order
- Preserve provider result order

---

## 10. External API Abstraction

Sampler must depend on a FlightProvider interface, not concrete APIs.

**Example:**

```ruby
provider.search(
  origin:,
  destination:,
  departure_date:,
  return_date:,
  passengers:,
  cabin_class:
)
```

Provider returns provider-native data. Sampler converts it.

---

## 11. Domain Object Definition

**Namespace:** Search::Sampling::Sampler

**Public API**

```ruby
def initialize(origin:, destination:, date_pairs:, passengers: 1, cabin_class: :economy)
end

def call
  # returns Array<flight_sample>
end
```

---

## 12. Implementation Constraints

- Plain Ruby
- No ActiveRecord
- No Sidekiq logic
- No retries
- No sleeps
- No rate limiting

Those belong to Runner or Jobs.

---

## 13. Failure Handling

Sampler may raise:

- Provider-level exceptions
- Network errors

Sampler must not swallow exceptions silently.

The Runner decides what to do.

---

## 14. Implementation Instructions

When implementing:

- Do not assume provider behavior
- Do not add caching
- Do not add retries
- Ask if provider interface is unclear

---

## 15. Explicitly Out of Scope (MVP)

- Multiple providers
- Provider fallback
- Deduplication across providers
- Currency conversion
- Parallel execution

---

End of document.
