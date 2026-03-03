# 📄 Domain Spec — SearchRun Repository (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md
- docs/domain/search_run.md

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

The **SearchRun Repository** is responsible for coordinating the execution of a SearchRun domain object and persisting its lifecycle and outputs.

It acts as the **consistency and transactional boundary** between:

- Domain execution (`Search::SearchRun`)
- Persistence models (`SearchRunRecord`, `FlightSample`, etc.)

It is the *only* component allowed to orchestrate domain execution **and** database writes together.

---

## 2. Responsibilities

The repository MUST:

- Load persistence records needed to run a search
- Instantiate the domain object via `SearchRunFactory`
- Execute the domain object
- Persist state transitions via `Search::Mappers::SearchRunMapper`
- Persist produced samples
- Guarantee transactional integrity

The repository MUST NOT:

- Contain business logic
- Implement sampling, scoring, or analysis rules
- Modify domain state directly
- Contain provider-specific logic

---

## 3. Inputs

The repository receives:

- **search_run_record** — ActiveRecord instance representing a persisted search run
- **provider** — Provider adapter implementing the search contract
- **max_candidates** (Integer)
- **passengers** (Integer)
- **cabin_class** (Symbol)

---

## 4. Outputs

```
Array  # normalized flight samples
```

Returned value is the same as the domain execution output.

---

## 5. Execution Flow (Normative)

### 5.1 High-Level Flow

1. Open a database transaction
2. Build domain object from persistence
3. Execute the domain object
4. Persist final domain state
5. Persist produced artifacts
6. Commit transaction

---

### 5.2 Detailed Steps

**Step 1 — Build domain object**

- Use `Search::Factories::SearchRunFactory.from_record`
- Factory MUST NOT mutate the record

---

**Step 2 — Persist initial state**

- Apply `Search::Mappers::SearchRunMapper` to persist:
  - `state`
  - `started_at`
- Save the record

---

**Step 3 — Execute domain**

- Call `Search::SearchRun#execute`
- Allow domain exceptions to propagate

---

**Step 4 — Persist final state**

- Apply `Search::Mappers::SearchRunMapper` again
- Persist:
  - `state`
  - `finished_at`
  - `error` (if present)

---

**Step 5 — Persist results**

- For each returned sample:
  - Create a `FlightSample` record
  - Associate it with the search run

---

**Step 6 — Transaction handling**

- If any error occurs:
  - Entire transaction MUST roll back
  - Domain exception MUST propagate

---

## 6. Transaction Guarantees

- All persistence MUST occur within a single database transaction
- Partial writes are forbidden
- Either:
  - Entire run is persisted
  - Or nothing is persisted

---

## 7. Error Handling Rules

| Scenario                | Behavior              |
|-------------------------|-----------------------|
| Domain raises error     | Rollback and re-raise |
| Persistence fails       | Rollback and raise    |
| Provider raises error   | Rollback and re-raise |
| Invalid domain state    | Raise immediately     |

The repository MUST NOT swallow exceptions.

---

## 8. What the Repository Must NOT Do

- 🚫 Retry execution
- 🚫 Catch and log errors
- 🚫 Implement async behavior
- 🚫 Modify domain logic
- 🚫 Call provider APIs directly
- 🚫 Perform scoring or analysis

---

## 9. Domain Object Definition

**Namespace**

```
Search::Repositories::SearchRunRepository
```

**Public API**

```ruby
def self.execute(
  search_run_record,
  provider:,
  max_candidates:,
  passengers:,
  cabin_class:
)
end
```

---

## 10. Persistence Dependencies

The repository is allowed to depend on:

- SearchRunRecord
- SearchIntent
- FlightSample (MVP)
- ActiveRecord transactions

It MUST NOT expose ActiveRecord objects outside its boundary.

---

## 11. Determinism Guarantee

Given:

- Same persisted input
- Same provider behavior

The repository MUST:

- Produce the same domain output
- Persist the same records
- Transition through the same states

---

## 12. Future Extensions (Explicitly Out of Scope)

- Async execution
- Background jobs
- Provider fan-out
- Cost budgets
- Scoring and ranking
- Incremental re-runs

These will extend the repository but MUST NOT change this contract.

---

## 13. Implementation Instructions

When implementing:

- Follow this document strictly
- Do not add retries or async logic
- Do not invent abstractions
- Do not add logging
- Ask before changing transaction boundaries

---

End of document.
