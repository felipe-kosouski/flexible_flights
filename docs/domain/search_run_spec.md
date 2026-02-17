# 📄 Domain Spec — SearchRun (Execution Contract, MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md
- docs/domain/search_run.md

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

This document defines the **behavioral contract** of a `SearchRun`.

It specifies **observable behavior**, not implementation details.

This document is normative for:

- RSpec examples
- Cursor implementation
- Future refactors

---

## 2. Scope

This spec governs:

- Search execution lifecycle
- Interaction with Sampling::Runner
- State transitions
- Error handling behavior
- Execution metadata

This spec does **not** govern:

- Sampling internals
- Scoring
- Persistence mechanisms
- Async execution

---

## 3. Inputs

A SearchRun is created with the following immutable inputs:

- origin (String)
- destination (String)
- earliest_departure_date (Date)
- latest_departure_date (Date)
- min_stay_days (Integer)
- max_stay_days (Integer)
- max_candidates (Integer)
- passengers (Integer, default = 1)
- cabin_class (Symbol, default = :economy)
- provider (Object implementing sampling provider interface)

---

## 4. Public API

```ruby
SearchRun#execute
```

---

## 5. Initial State

Upon creation:

- state = :initialized
- started_at = nil
- finished_at = nil
- error = nil
- results = empty collection

No side effects occur at initialization.

---

## 6. Execution — Happy Path

**Scenario:** Successful execution with results

**Given**

- A SearchRun in state :initialized
- Valid input parameters
- Sampling::Runner returns one or more samples

**When**

- execute is called

**Then**

1. state transitions to :sampling
2. started_at is set
3. Sampling::Runner is invoked exactly once with SearchRun inputs
4. Returned samples are stored as results
5. finished_at is set
6. state transitions to :completed
7. error remains nil

---

## 7. Execution — Empty Result Set

**Scenario:** Sampling returns an empty array

**Given**

- Sampling::Runner returns []

**When**

- execute is called

**Then**

- Execution is considered successful
- state transitions to :completed
- results is an empty collection
- finished_at is set
- error remains nil

---

## 8. Execution — Failure Path

**Scenario:** Sampling raises an exception

**Given**

- Sampling::Runner raises any exception

**When**

- execute is called

**Then**

1. state transitions to :sampling
2. started_at is set
3. state transitions to :failed
4. finished_at is set
5. error is set to the raised exception
6. The exception is re-raised

No retries occur.

---

## 9. Execution — Idempotency Rules

**Scenario:** execute called more than once

**Given**

- A SearchRun in state :completed OR :failed

**When**

- execute is called again

**Then**

- An error is raised (e.g. InvalidStateError)
- Sampling::Runner is NOT called
- No state is changed

Re-execution is forbidden.

---

## 10. Interaction Contract with Sampling::Runner

SearchRun must:

- Instantiate Sampling::Runner with:
  - origin
  - destination
  - earliest_departure_date
  - latest_departure_date
  - min_stay_days
  - max_stay_days
  - max_candidates
  - passengers
  - cabin_class
  - provider
- Call Sampling::Runner.call(...) exactly once

SearchRun must NOT:

- Modify Sampling::Runner output
- Rescue provider-level errors
- Retry runner execution

---

## 11. Timing Guarantees

- started_at is set before calling Sampling::Runner
- finished_at is set after Sampling::Runner completes or fails
- finished_at > started_at (strictly)

---

## 12. State Guarantees

| State      | Allowed? | Notes                    |
|------------|----------|--------------------------|
| initialized| ✅       | Initial state only       |
| sampling   | ✅       | During execution only    |
| completed  | ✅       | Terminal state           |
| failed     | ✅       | Terminal state           |

No other states are allowed.

---

## 13. What SearchRun Must NOT Do

- 🚫 Call flight APIs directly
- 🚫 Perform scoring
- 🚫 Retry failures
- 🚫 Schedule background jobs
- 🚫 Perform async execution
- 🚫 Enforce provider contracts

---

## 14. Determinism Guarantee

Given identical inputs and identical Sampling::Runner behavior:

- State transitions are deterministic
- Results are deterministic
- Errors are deterministic

---

## 15. Future Extensions (Explicitly Out of Scope)

- Async execution
- Retry logic
- Partial failure handling
- Multi-provider sampling
- Scoring & ranking
- Persistence optimizations

---

## 16. Domain Object Definition

**Namespace**

Search::SearchRun

**Public API**

```ruby
def execute
  # executes sampling lifecycle
end
```

---

## 17. Cursor Instruction

When implementing:

- Follow this document strictly
- Do not add retries
- Do not swallow errors
- Do not infer async behavior
- Raise if state invariants are violated

If anything is ambiguous, ask.

---

End of document.
