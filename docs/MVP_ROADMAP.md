# MVP Roadmap

This document captures the implementation roadmap we discussed so we keep focus on what is still required for MVP.

It is not a replacement for `PRODUCT_GUIDE.md` or `PRD.md`; it is a practical execution checklist derived from them.

---

## 1) Ranking ✅ DONE

**Goal**

- Produce a deterministic ranked list of flights for each search run.

**Completed**

- `Ranking::Ranker` and `RankedFlight` implemented and spec-covered.
- Ranking phase wired in `SearchExecution` as phase 7.
- `ranked_results` is the canonical ordered output consumed by insights and repository.

---

## 2) Persistence Layer Review ✅ DONE

**Goal**

- Ensure DB schema + ActiveRecord models match domain vocabulary, constraints, and read/write needs.

**Completed**

- Schema aligned with domain vocabulary (`state`, `finished_at`, integer cents, integer enums).
- `analysis_snapshots.volatility` stored as integer (enum semantics); `confidence_level` as integer.
- `flight_samples.luggage_included` has `null: false` constraint; AR validation enforced.
- `search_intents` index scoped to `user_id` only (not over-constrained).
- Foreign keys and indexes reviewed and in place.

---

## 3) Insights ✅ DONE

**Goal**

- Build the domain that answers: best time to travel, book now vs wait, supporting rationale.

**Completed**

- `Insights::Builder`, `SearchInsights`, `DateRangeInsight`, `WaitOrBookInsight`, `PriceRarityInsight` implemented.
- All 4 artifacts produced: `best_time_to_travel`, `wait_or_book`, `price_rarity`, `cheapest_comfort_window`.
- Confidence-gated within the domain: low confidence suppresses recommendations and returns `:insufficient_data`.
- Integrated in `SearchExecution` as phase 8.
- Spec coverage in `spec/domain/search/insights/`.

---

## 4) Job Orchestration Strategy ✅ DONE

**Goal**

- Choose and implement one coherent execution entrypoint.

**Decision**

- Single `SearchRunJob` wraps the synchronous repository pipeline in an async job.
- Repository owns all state transitions, error handling, and persistence.
- Old multi-job stubs (`StartSearchRunJob`, `SamplingJob`, `AnalysisJob`) removed.
- Solid Queue wired as backend; `worker: bin/jobs` in `Procfile.dev`.

**Documented pattern**

- Controller creates `SearchRun` record → enqueues `SearchRunJob` → job delegates to `SearchRunRepository.execute`.
- Job is intentionally thin. Errors propagate to Solid Queue for tracking.

---

## 5) Provider Integrations via Base Abstraction

**Goal**

- Integrate real flight providers behind a stable provider contract.

**Why it matters**

- Sampling quality and coverage depend on real provider data.
- A base abstraction keeps integration consistent and swap-friendly.
- Current pipeline uses an injected provider stub; no real provider is wired.

**Target shape**

- A provider interface/base object defining required methods and response contract.
- Adapter implementations per provider (normalize upstream payloads to domain input shape).
- Deterministic error/timeout handling at the orchestration boundary.

**Expected output**

- One fully integrated provider end-to-end, plus scaffolding for additional providers.

---

## 6) Presentation Layer

**Goal**

- Render the user-facing Smart Search result page and all its states.

**Why it matters**

- MVP value is delivered through what users can see and understand.
- The full domain pipeline is complete — only the UI delivery layer is missing.

**Must include**

- Search form wired to controller → `SearchRunJob` enqueue.
- Polling or Turbo Streams for async result delivery.
- Insight summary block (best time, book/wait recommendation).
- Ranked flight list with per-flight score context and explanation.
- UI states: loading, success, low-confidence, failed/empty.

**Expected output**

- End-to-end UI flow: search submission → async execution → results page.

---

## 7) Confidence Gating in Presentation

**Goal**

- Surface confidence-driven behavior in the UI, not just in the domain.

**Why it matters**

- Domain already gates insights by confidence (low → suppressed or `:insufficient_data`).
- PRD requires confidence-aware messaging in the UI: wording, tone, visual cues must reflect confidence level.

**Current gap**

- Domain confidence policy is in place. Presentation layer does not yet consume or render it.

**Expected output**

- Explicit UI rules mapping confidence levels to message tone and visual state:
  - `:high` → confident recommendation copy.
  - `:medium` → hedged copy ("prices suggest…").
  - `:low` → "not enough data" state with no recommendation shown.

---

## Suggested Execution Order

1. ~~Ranking~~ ✅
2. ~~Persistence review~~ ✅
3. ~~Job orchestration decision~~ ✅
4. ~~Insights domain~~ ✅
5. Provider base abstraction + first real provider.
6. Presentation layer (search form → async job → results page).
7. Confidence gating in presentation (UI messaging by confidence level).

---

## Definition of Done (MVP)

MVP is complete when a user can run one Smart Search and receive:

- A ranked list of flights with explainable scoring context.
- A best-time-to-travel insight.
- A deterministic book-vs-wait recommendation that is confidence-gated.
- Clear UI states for success, low-confidence, and failure.
