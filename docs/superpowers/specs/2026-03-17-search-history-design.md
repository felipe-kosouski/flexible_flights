# Search History — Design Spec

**Date:** 2026-03-17
**Status:** Approved
**Scope:** Search history page, "Run again" pre-fill, freshness indicator on results

---

## Context

Users can run Smart Searches and view results, but there is no way to return to a past search after closing the tab. This spec adds a history page listing all of a user's SearchRuns, a "Run again" flow that pre-fills the new search form, and a freshness indicator on results pages.

---

## Sub-project scope

This is Sub-project A of a larger "user area" effort. Sub-project B (profile page, change password, delete account) is separate.

---

## Feature 1: Search History Page

### Route

```
GET /history  →  SearchHistoryController#index
```

### Controller

`SearchHistoryController` has one action: `index`. It loads all SearchRuns belonging to the current user, eager-loads `search_intent`, and orders by `created_at DESC`.

```ruby
@search_runs = current_user.search_runs.includes(:search_intent).order(created_at: :desc)
```

Authentication: `before_action :authenticate_user!`

### View

`app/views/search_history/index.html.erb` — a table/card list. Each row shows:

| Field | Source |
|-------|--------|
| Route | `search_intent.origin_airport → search_intent.destination_airport` |
| Date window | `search_intent.earliest_departure – search_intent.latest_return` |
| Stay range | `search_intent.min_stay_days – search_intent.max_stay_days nights` |
| Status badge | `completed` (green) · `failed` (red) · `in progress` (amber + spinner) |
| Run date | `finished_at` formatted as relative time ("3 days ago"); falls back to `created_at` if still running |
| Actions | "View results" link (completed only) · "Run again" link (all rows) |

Rows are ordered newest first. All states are shown (completed, failed, in-progress).

### Presenter

`SearchHistoryPresenter` wraps a single SearchRun for display. Exposes:
- `route` — "JFK → LIS"
- `date_window` — "Apr 1 – Apr 30"
- `stay_range` — "5–10 nights"
- `status_label` — "Completed" / "Failed" / "In progress"
- `status_color_class` — Tailwind color classes per status
- `run_at` — relative timestamp string ("3 days ago")
- `view_results_path` — `search_path(search_run)` if completed, else `nil`
- `run_again_path` — `new_search_path(from_intent: search_run.search_intent_id)`

### Nav

A "History" link is added to the application layout nav, between the logo and the user email/sign-out area. Only shown when `user_signed_in?`.

---

## Feature 2: "Run Again" Pre-fill

### How it works

The "Run again" link on the history page links to:
```
GET /searches/new?from_intent=<search_intent_id>
```

`SearchesController#new` checks for the `from_intent` param. If present, it loads the matching SearchIntent **scoped to `current_user`** (IDOR protection) and pre-populates the form.

The controller already has a class-level `rescue_from ActiveRecord::RecordNotFound`. To avoid that handler firing for `from_intent` misses (which would redirect with a noisy alert and leak that the ID exists), the lookup uses `find_by` + nil check instead of `find`:

```ruby
def new
  @search_intent = if params[:from_intent]
    intent = current_user.search_intents.find_by(id: params[:from_intent])
    intent ? intent.dup.tap { |d| d.user_id = nil } : SearchIntent.new
  else
    SearchIntent.new
  end
end
```

`intent.dup` creates an unsaved copy so the form is pre-filled but submitting creates a new SearchIntent. `user_id` is explicitly cleared on the dup — `ActiveRecord::Base#dup` copies all attributes including `user_id`, which would be semantically incorrect on an unsaved object not yet owned by `current_user`.

If `from_intent` refers to another user's intent (or a non-existent ID), `find_by` returns `nil` and the form renders blank with no alert — no information is leaked.

---

## Feature 3: Freshness Indicator

### On the results page

Both `_results.html.erb` and `_low_confidence.html.erb` show a freshness line below the route header. This is driven by two new methods on `SearchResultsPresenter`:

- `stale?` — returns `true` if `search_run.finished_at < 7.days.ago` (strictly older than 7 days; exactly 7 days ago is considered stale)
- `freshness_label` — returns a human-readable string:
  - Fresh (< 7 days): `"Analysed 2 days ago"`
  - Stale (≥ 7 days): `"Analysed 12 days ago · consider running again"`

When stale, the freshness line includes a "Run again →" link to `new_search_path(from_intent: search_run.search_intent_id)`.

### On the history page

Each row already shows `run_at` ("3 days ago"). No additional freshness treatment needed on the history page.

---

## Routes

```ruby
get "history", to: "search_history#index", as: :search_history
```

Added alongside the existing routes in `config/routes.rb`.

---

## Files

| Action | File | Purpose |
|--------|------|---------|
| Create | `app/controllers/search_history_controller.rb` | `index` action |
| Create | `app/presenters/search_history_presenter.rb` | Per-row display logic |
| Create | `app/views/search_history/index.html.erb` | History page template |
| Modify | `app/controllers/searches_controller.rb` | `new` handles `from_intent` param |
| Modify | `app/presenters/search_results_presenter.rb` | Add `stale?` + `freshness_label` |
| Modify | `app/views/searches/_results.html.erb` | Render freshness indicator |
| Modify | `app/views/searches/_low_confidence.html.erb` | Render freshness indicator |
| Modify | `app/views/layouts/application.html.erb` | Add "History" nav link |
| Modify | `config/routes.rb` | Add `/history` route |
| Create | `spec/requests/search_history_spec.rb` | Access control + ordering specs |
| Modify | `spec/requests/searches_spec.rb` | Pre-fill specs |
| Modify | `spec/presenters/search_results_presenter_spec.rb` | `stale?` + `freshness_label` specs |

---

## Testing

### `SearchHistoryController` (request specs)
- Unauthenticated `GET /history` redirects to sign in
- Authenticated user sees only their own SearchRuns
- Runs are ordered newest first — fixture must create runs with explicit out-of-order `created_at` values to avoid a trivially passing test
- User with no runs sees an empty state

### `SearchesController#new` with `from_intent` (request specs)
- With valid `from_intent` belonging to current user: form pre-filled (response 200)
- With `from_intent` belonging to another user: form renders blank (no error)
- Without `from_intent`: form renders blank as before

### `SearchResultsPresenter` (unit specs)
- `stale?` returns `false` when `finished_at` is 6 days ago
- `stale?` returns `true` when `finished_at` is exactly 7 days ago
- `stale?` returns `true` when `finished_at` is 8 days ago
- `freshness_label` returns short form when fresh
- `freshness_label` returns "consider running again" copy when stale

---

## Out of Scope

- Grouping history by SearchIntent (deferred — Option A chosen explicitly)
- Pagination of history (deferred)
- Deleting individual search runs from history
- Search history for Sub-project B (profile page, account settings)
