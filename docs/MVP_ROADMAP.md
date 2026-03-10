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

## 5) Provider Integrations via Base Abstraction ✅ DONE

**Goal**

- Integrate real flight providers behind a stable provider contract.

**Completed**

- `Flights::Base` defines the provider interface: `search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:) → Array<Hash>`.
- Domain error hierarchy (`Flights::Error`, `TimeoutError`, `RateLimitError`, `AuthError`, `InvalidResponse`) defined in a Zeitwerk explicit namespace file (`app/providers/flights.rb`).
- `Flights::Stub` returns hardcoded flights; used in development and as the default in `SearchRunJob`.
- `Flights::Registry` maps string names → provider instances, enabling ActiveJob-safe serialization (`provider_name: "amadeus"` rather than a Ruby object).
- `Flights::Amadeus::Client` — Faraday HTTP client with OAuth2 token caching (60 s expiry buffer) and typed error mapping.
- `Flights::Amadeus::Normalizer` — pure data transformation: raw Amadeus offer hash → canonical 8-field hash (`price_cents`, `currency`, `airline_codes`, `stops`, `air_time_minutes`, `layover_time_minutes`, `luggage_included`, `raw_provider`). Returns `nil` for malformed offers.
- `Flights::Amadeus::Provider` — thin adapter: calls client, feeds each offer to normalizer, drops nils.
- `SearchRunJob` updated to accept `provider_name:` string; resolves provider via registry inside `perform`.
- Full spec coverage: client (6), normalizer (16), provider (5), registry (3). 434 examples, 0 failures.

---

## 6) Results Read Layer ✅ DONE

**Goal**

- Give the presentation layer access to scored, ranked, and insight data after the async job completes.

**Decision: recompute on demand**

Scoring, ranking, explaining, and insights are pure Ruby with no I/O — microseconds. Raw `flight_samples` and `analysis_snapshot` are already persisted. No new schema is needed.

A `SearchRunRepository.load_results` method loads the stored raw data and reruns the compute-only pipeline phases on every read. Raw data is the source of truth; computed results are always derived.

**Completed**

- `Search::Factories::AnalysisSnapshotFactory.from_record` — hydrates `Models::AnalysisSnapshot` from the AR `AnalysisSnapshot` record (converts integer enum strings to symbols).
- `Search::SearchResults` — frozen Struct value object carrying `ranked_flights`, `insights`, `snapshot`.
- `SearchRunRepository.load_results(search_run_record)` — loads snapshot + samples, runs Scorer → Explanation::Builder → Ranker → Insights::Builder, returns `SearchResults`. Returns `nil` if no snapshot exists (still running / failed / empty).
- Spec coverage: factory (7 examples), repository `load_results` (10 examples). 451 examples, 0 failures.

---

## 7) Presentation Layer ✅ DONE

**Goal**

- Render the user-facing Smart Search result page and all its states.

**Completed**

- `SearchesController` with `new`, `create`, `show` actions; session-based guest user.
- Search form (`searches/new`) wired to controller → `SearchRunJob` enqueue.
- Turbo Streams + Solid Cable for live async result delivery from the Solid Queue worker process (`async` adapter replaced with `solid_cable` in development).
- `SearchRunJob#broadcast_result` in `ensure` block — broadcasts `searches/results` or `searches/failed` partial after job completes.
- Presenters: `SearchResultsPresenter`, `RankedFlightPresenter`, `InsightsPresenter`.
- UI states: loading spinner, success (ranked flights + insights), failed.
- Per-flight cards: score ring badge, price/dates, stops/duration/luggage, score breakdown, human-readable explanation summary + tradeoffs.
- Insight cards: best time to travel, wait-or-book recommendation, price rarity, cheapest comfort window.
- Rails 8 per-environment encrypted credentials (`bin/rails credentials:edit --environment development`) wired to Amadeus provider and `flight_provider` key in `SearchRunJob`.
- End-to-end verified with real Amadeus data in development.

---

## 8) Confidence Gating in Presentation

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
5. ~~Provider base abstraction + first real provider.~~ ✅
6. ~~Results read layer (recompute on demand from stored raw data).~~ ✅
7. ~~Presentation layer (search form → async job → results page).~~ ✅
8. Confidence gating in presentation (UI messaging by confidence level).

---

## Definition of Done (MVP)

MVP is complete when a user can run one Smart Search and receive:

- A ranked list of flights with explainable scoring context.
- A best-time-to-travel insight.
- A deterministic book-vs-wait recommendation that is confidence-gated.
- Clear UI states for success, low-confidence, and failure.
