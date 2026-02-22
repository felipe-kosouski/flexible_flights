# 🏗 Architecture Overview — Modular Monolith (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md
- CURSOR_RULES.md
- docs/domain/*

If conflicts exist, higher-level documents prevail.

---

## 1. Architectural Style

This application follows a **Modular Monolith** architecture with a **rich domain layer**.

### Core principles

- Strong domain boundaries
- Explicit orchestration
- Persistence is an implementation detail
- Deterministic, testable business logic
- No "smart" ActiveRecord models
- Domain logic operates on **domain representations**, not AR models

---

## 2. High-Level Module Structure

```
app/
├── domain/
│   └── search/
│       ├── search_run.rb
│       │
│       ├── models/                # Domain read models (NOT ActiveRecord)
│       │   ├── flight_sample.rb
│       │   └── search_intent.rb
│       │
│       ├── sampling/
│       ├── scoring/
│       ├── factories/
│       ├── mappers/
│       └── repositories/
│
├── models/
│   ├── search_intent.rb
│   ├── search_run.rb
│   ├── flight_sample.rb
│   └── analysis_snapshot.rb
```

---

## 3. Domain vs Persistence Split

### Domain Layer (`app/domain`)

- Plain Ruby objects
- No ActiveRecord
- No database access
- No callbacks
- No implicit side effects
- Deterministic and synchronous
- Operates on **domain-owned representations**

**Includes:**

- Core domain entities
- Scoring and sampling logic
- Domain read models (projections of persisted data)

**Examples:**

- `Search::SearchRun`
- `Search::Scoring::*`
- `Search::Models::FlightSample`
- `Search::Models::SearchIntent`

---

### Domain Read Models (`app/domain/**/models`)

Domain read models are **read-only representations** of persisted data, shaped for business logic.

They:

- Wrap ActiveRecord models or hashes
- Expose domain semantics (e.g. `stay_length_days`)
- Hide persistence concerns
- Contain **no validations**
- Contain **no persistence logic**
- Are safe to use inside scoring and decision logic

They are **not** ActiveRecord models.

---

### Persistence Layer (`app/models`)

- ActiveRecord models
- Validation & associations only
- No orchestration logic
- No external API calls
- No domain rules

**Examples:**

- `SearchRun`
- `SearchIntent`
- `FlightSample`

---

## 4. Orchestration Flow (Search Execution)

```
Search::Repositories::SearchRunRepository.execute
↓
Search::Factories::SearchRunFactory.from_record
↓
Search::SearchRun (domain)
↓
Sampling::Runner
↓
Provider API
↓
Domain results
↓
Search::Mappers::SearchRunMapper.apply
↓
Persist FlightSamples
```

**Note:**  
Scoring and decision logic operate on **domain read models**, not on ActiveRecord instances.

---

## 5. Repositories

Repositories are the **only place** where:

- Transactions are opened
- Domain execution is triggered
- Persistence is coordinated

**Rules:**

- Repositories may call domain objects
- Domain objects must never call repositories
- Repositories translate domain state → database state
- Repositories may construct domain read models

---

## 6. Factories vs Mappers

### Factories

- One-way
- Create **domain objects and domain read models** from persistence
- Never mutate ActiveRecord objects

**Example:**

- `Search::Factories::SearchRunFactory.from_record`

---

### Mappers

- Translate **domain → persistence**
- Apply state changes
- Do not execute domain logic

**Example:**

- `Search::Mappers::SearchRunMapper.apply`

---

## 7. State Management

### Domain (`Search::SearchRun`)

**States:**

- `:initialized`
- `:sampling`
- `:completed`
- `:failed`

**Attributes:**

- `started_at`
- `finished_at`
- `error`
- `results`

---

### Persistence (`SearchRun` AR)

- `state` (enum)
- `started_at`
- `finished_at`
- `error_message`

**Naming is authoritative:**

- `state` (NOT `status`)
- `finished_at` (NOT `completed_at`)

---

## 8. Transactions & Failure Semantics

- Domain execution happens **inside** a transaction
- Domain failures:
  - Roll back samples
  - Persist failed state **outside** the transaction
  - Error is re-raised

This ensures:

- No partial data
- Accurate run history
- Correct retry behavior

---

## 9. Explicit Non-Goals (MVP)

Out of scope:

- Async execution
- Background jobs
- Caching
- Pricing heuristics
- Adaptive re-sampling
- Provider fallback chains

These will be layered later without breaking contracts.

---

## 10. Determinism Guarantee

Given identical inputs:

- Domain outputs must be identical
- Ordering must be deterministic
- No randomness is allowed unless explicitly introduced

---

End of document.