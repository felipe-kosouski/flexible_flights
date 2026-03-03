# MVP Roadmap

This document captures the implementation roadmap we discussed so we keep focus on what is still required for MVP.

It is not a replacement for `PRODUCT_GUIDE.md` or `PRD.md`; it is a practical execution checklist derived from them.

---

## 1) Ranking (In Progress)

**Goal**
- Produce a deterministic ranked list of flights for each search run.

**Why it matters**
- The product must show the best options first, not just scored data.
- PRD/scoring rules define clear ordering semantics.

**Current status**
- Ranking phase exists in `SearchExecution`.
- `RankedFlight` and `Ranker` are implemented.

**Remaining work**
- Validate ranking output contract in the eventual presentation/query path.
- Ensure rank consumers use `ranked_results` as the canonical ordered list.

---

## 2) Persistence Layer Review

**Goal**
- Ensure DB schema + ActiveRecord models match domain vocabulary, constraints, and read/write needs.

**Why it matters**
- Persistence is the source of truth for facts (`search_runs`, `flight_samples`, `analysis_snapshots`).
- Misaligned schema constraints create subtle runtime bugs.

**Known review points**
- `search_intents` unique index scoping (currently likely too restrictive).
- `luggage_included` boolean validation behavior.
- `analysis_snapshots.volatility_index` storage type vs domain usage (float vs symbol/enum semantics).

**Expected output**
- List of migration/model fixes with backward-compatible rollout order.

---

## 3) Provider Integrations via Base Abstraction

**Goal**
- Integrate real flight providers behind a stable provider contract.

**Why it matters**
- Sampling quality and coverage depend on provider implementations.
- A base abstraction keeps integration consistent and swap-friendly.

**Target shape**
- A provider interface/base object defining required methods and response contract.
- Adapter implementations per provider (normalize upstream payloads to domain input shape).
- Deterministic handling of provider errors/timeouts in orchestration boundaries.

**Expected output**
- One fully integrated provider end-to-end, plus scaffolding for additional providers.

---

## 4) Presentation Layer

**Goal**
- Render the user-facing Smart Search result page and states.

**Why it matters**
- MVP value is delivered through what users can see and understand.

**Must include**
- Insight summary block above flights.
- Ranked flight list with clear explanation hooks.
- Confidence-aware messaging.
- Empty/failed/loading states.

**Expected output**
- End-to-end UI flow from search submission to results display.

---

## 5) Insights (Critical Missing Domain)

**Goal**
- Build the domain that answers:
  - Best time to travel
  - Book now vs wait
  - Supporting rationale

**Why it matters**
- This is core product value in `PRODUCT_GUIDE.md`, not an optional enhancement.
- Current explanation logic is per-flight; insights are cross-flight and decision-oriented.

**Current gap**
- No insight domain objects.
- No best-window derivation logic.
- No deterministic recommendation policy object.

**Expected output**
- Insight domain objects and builders, deterministic and confidence-aware.

---

## 6) Job Orchestration Strategy

**Goal**
- Choose and implement one coherent execution entrypoint:
  - synchronous repository pipeline, or
  - asynchronous job-driven pipeline.

**Why it matters**
- The codebase currently has empty job stubs while repository executes synchronously.
- Mixed orchestration models create drift and operational ambiguity.

**Decision to make**
- If jobs are canonical: wire `StartSearchRunJob`, `SamplingJob`, `AnalysisJob` properly and adjust repository role.
- If repository is canonical: remove/deprecate unused job stubs to reduce confusion.

**Expected output**
- Single documented orchestration path with tests and lifecycle guarantees.

---

## 7) Confidence as a Gating Mechanism

**Goal**
- Use confidence to control recommendation strength and wording, not just store it.

**Why it matters**
- PRD and PRODUCT_GUIDE require confidence-gated behavior:
  - low confidence must avoid strong advice
  - stale/weak signals must not produce decisive recommendations

**Current gap**
- Confidence is computed in analysis but not enforced in decision/presentation behavior.

**Expected output**
- Explicit policy rules mapping confidence levels to allowed recommendation types and message tone.

---

## Suggested Execution Order

1. Finish ranking integration verification in consumers.
2. Persistence review + schema/model corrections.
3. Decide orchestration model (jobs vs repository) and align execution path.
4. Implement provider base abstraction + first real provider.
5. Implement Insights domain (best time + book/wait).
6. Add confidence gating policy through insights and presentation.
7. Complete final presentation layer wiring and UX polish.

---

## Definition of Done (MVP)

MVP is complete when a user can run one Smart Search and receive:
- A ranked list of flights with explainable scoring context.
- A best-time-to-travel insight.
- A deterministic book-vs-wait recommendation that is confidence-gated.
- Clear UI states for success, low-confidence, and failure.

