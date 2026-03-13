# Temporal Price Trends

## Goal

Enable the route summary to answer questions that require historical context:

- "In the last 30 days, prices this low appeared in only 2 of 8 searches for this route."
- "Prices on this route have been rising over the past month."
- "On this route, booking now saves roughly $80 compared to waiting until the last two weeks."

---

## Current limitation

`AnalysisSnapshot` captures statistics for a single search run in isolation. It has no awareness of past runs, so the route summary can only speak to the current snapshot's price band and volatility — not to how those compare to history.

---

## Three signals to add

### Signal 1 — Price frequency

**What it answers:** How rare is this price level for this route?

**How it's computed:** Query all completed `SearchRuns` for the same (origin, destination) pair in the last 30 days. Count how many had a median price (`price_p50_cents`) at or below the current run's median.

**New fields on `AnalysisSnapshot`:**

- `comparable_search_count` — total historical runs found
- `times_this_cheap` — runs where historical p50 ≤ current p50

**Example copy:** "Only 2 of the last 8 searches on this route found prices this low."

---

### Signal 2 — Price trend direction

**What it answers:** Are prices moving up or down on this route?

**How it's computed:** Using the same historical runs, compare the oldest median to the newest. A > 10% change is classified as rising or falling; otherwise stable. Requires at least 3 historical runs to be meaningful.

**New field on `AnalysisSnapshot`:**

- `price_trend` — `:rising`, `:stable`, `:falling`, or `nil`

**Example copy:** "Prices on this route have been climbing over the past month."

---

### Signal 3 — Lead-time price buckets

**What it answers:** Does booking earlier actually save money on this route?

**How it's computed:** Across all historical flight samples for the same route, group by how many days before departure the search happened (derived as `departure_datetime.to_date − search_run.created_at.to_date`). Compute median price per bucket:

| Bucket        | Days before departure |
| ------------- | --------------------- |
| `early`       | 60+ days              |
| `mid`         | 30–60 days            |
| `late`        | 14–30 days            |
| `last_minute` | < 14 days             |

**New field on `AnalysisSnapshot`:**

- `lead_time_prices` — JSONB: `{early: cents, mid: cents, late: cents, last_minute: cents}` (nil buckets when insufficient data)

**Example copy:** "On this route, booking now (55 days out) is typically about $90 cheaper than waiting until the last two weeks."

**Note:** This signal requires data accumulation. Buckets will return `nil` until enough samples exist per bucket. It ships as nullable from day one.

---

## Data available (no new collection needed)

| Source                                                | Field                 | Used for                   |
| ----------------------------------------------------- | --------------------- | -------------------------- |
| `analysis_snapshots.price_p50_cents`                  | Median per run        | Signals 1 + 2              |
| `analysis_snapshots.created_at`                       | When the run happened | Signal 2 ordering          |
| `search_intents.origin_airport + destination_airport` | Route identity        | Cross-run grouping         |
| `flight_samples.price_cents`                          | Per-flight price      | Signal 3                   |
| `flight_samples.departure_datetime`                   | Target departure      | Signal 3 (days calc)       |
| `search_runs.created_at`                              | When sampled          | Signal 3 (days calc proxy) |

---

## Architecture

### New components

**`Search::RouteHistory`** — `app/domain/search/models/route_history.rb`

Pure Ruby domain value object. Carries raw historical data into the domain layer without any AR dependency.

```ruby
RouteHistory = Data.define(
  :historical_medians,   # [{price_cents:, searched_at:}, ...]
  :lead_time_samples     # [{price_cents:, days_before_departure:}, ...]
)
```

---

**`Search::RouteHistoryQuery`** — `app/domain/search/repositories/route_history_query.rb`

AR query at the repository layer. Joins `search_runs → search_intents → analysis_snapshots` (for Signal 1+2) and `search_runs → flight_samples` (for Signal 3). Excludes the current in-progress run. Returns a `RouteHistory` domain object.

```ruby
RouteHistoryQuery.call(origin: "GRU", destination: "LHR", lookback_days: 30)
# => RouteHistory
```

---

**Updated `SnapshotBuilder`**

New optional argument: `route_history: nil`. When present, computes and sets the three new fields on `AnalysisSnapshot`. Existing behavior unchanged when `nil`.

```ruby
SnapshotBuilder.build(flight_samples, route_history: route_history)
```

---

**Updated `SearchExecution`**

Threads `route_history:` through to `SnapshotBuilder`. No other changes.

```ruby
SearchExecution.new(search_run:, intent:, route_history: nil)
```

---

**Updated `SearchRunRepository`**

Before executing, queries route history and passes it into the pipeline. After execution, persists the new fields.

---

### Schema changes

Migration: add to `analysis_snapshots`

| Column                    | Type    | Notes                                        |
| ------------------------- | ------- | -------------------------------------------- |
| `comparable_search_count` | integer | nullable                                     |
| `times_this_cheap`        | integer | nullable                                     |
| `price_trend`             | integer | nullable enum: 0=falling, 1=stable, 2=rising |
| `lead_time_prices`        | jsonb   | nullable                                     |

---

## Implementation order

1. Migration + AR model (`price_trend` enum)
2. `RouteHistory` domain value object
3. `RouteHistoryQuery` AR query
4. `AnalysisSnapshot` domain model — add 4 new nullable fields
5. `SnapshotBuilder` — accept `route_history:`, compute new fields
6. `SearchExecution` — thread `route_history:` through
7. `SearchRunRepository` — query, pass in, persist new fields
8. `RouteSummaryCopyService` — include new fields in prompt when present

---

## Behaviour on first search for a route

All new fields return `nil`. The route summary falls back to volatility-only signals. No change to existing behaviour.

From the second search on the same route, Signal 1 and 2 populate. Signal 3 populates once enough samples exist per lead-time bucket.
