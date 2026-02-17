# 📄 Domain Spec — Search Run (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md
- docs/domain/sampling.md

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

A Search Run represents **one complete execution of a flight search**.

It is responsible for:

- Orchestrating the sampling pipeline
- Tracking execution lifecycle
- Recording execution metadata and results

It is the **boundary object** between product intent and sampling execution.

---

## 2. Inputs

A Search Run is initialized with:

- **origin** (String)
- **destination** (String)
- **earliest_departure_date** (Date)
- **latest_departure_date** (Date)
- **min_stay_days** (Integer)
- **max_stay_days** (Integer)
- **max_candidates** (Integer)
- **provider** (Provider interface)

Optional:

- **passengers** (Integer, default: 1)
- **cabin_class** (Symbol, default: :economy)

---

## 3. Outputs

```
Array
```

Where each hash represents a **normalized sampled flight**, as returned by `Search::Sampling::Runner`.

The array may be empty.

---

## 4. Pre-Conditions

- Inputs are assumed valid
- No input validation errors are raised at this layer
- A Search Run may only be executed once

---

## 5. Execution Lifecycle

### 5.1 States

A Search Run has one of the following states:

- `initialized`
- `running`
- `completed`
- `failed`

---

### 5.2 Lifecycle Rules (Normative)

1. A newly created Search Run starts in `initialized`
2. Calling `execute` transitions state to `running`
3. On successful completion, state becomes `completed`
4. If any error is raised, state becomes `failed`
5. A completed or failed run MUST NOT be executed again

---

## 6. Execution Flow (Normative)

When `execute` is called:

1. Record `started_at`
2. Transition state to `running`
3. Call `Search::Sampling::Runner.call` with stored inputs
4. Capture returned samples
5. Persist execution metadata
6. Record `finished_at`
7. Transition state to `completed`
8. Return samples

If an error occurs at any step:

- Capture error metadata
- Transition state to `failed`
- Re-raise the error

---

## 7. Metadata Captured

Each Search Run records:

- **started_at**
- **finished_at**
- **duration_ms**
- **total_candidates_generated** (if available)
- **total_candidates_sampled**
- **total_samples_returned**

On failure:

- **error_class**
- **error_message**

---

## 8. Invariants

- Inputs are immutable after initialization
- Execution is idempotent only by prevention (not retries)
- Partial results are not persisted
- Errors are never swallowed

---

## 9. What SearchRun Must NOT Do

- 🚫 Generate date grids
- 🚫 Select sampling candidates
- 🚫 Call provider APIs directly
- 🚫 Normalize flight data
- 🚫 Score or rank results
- 🚫 Retry failed operations
- 🚫 Run asynchronously

It delegates all domain logic.

---

## 10. Collaborators

SearchRun depends on:

- `Search::Sampling::Runner`
- Persistence layer (e.g., ActiveRecord)

No other collaborators are allowed.

---

## 11. Edge Cases

| Case                      | Behavior                    |
|---------------------------|----------------------------|
| No date pairs generated   | Complete with empty result |
| No candidates selected    | Complete with empty result |
| Provider raises error     | Mark failed, re-raise error|
| execute called twice       | Raise error                |

---

## 12. Domain Object Definition

**Namespace**

Search::SearchRun

**Public API**

```ruby
def self.create(...)
end

def execute
  # returns Array<Hash>
end
```

---

## 13. Implementation Constraints

- Plain Ruby domain logic
- No business logic duplication
- No retries
- No async primitives
- No background jobs
- No framework-specific callbacks

---

## 14. Cursor Instruction

When implementing:

- Follow this document strictly
- Do not add orchestration logic
- Do not introduce retries or async
- Persist only what is explicitly defined
- Ask before extending behavior

---

End of document.
