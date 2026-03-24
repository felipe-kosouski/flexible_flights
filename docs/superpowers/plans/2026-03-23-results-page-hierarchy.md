# Results Page Hierarchy Implementation Plan

> **Status: COMPLETE** — All tasks implemented and reviewed (2026-03-24).

**Goal:** Restructure `_results.html.erb` so the recommendation card is the hero and flights are secondary, framed as "The flights behind this recommendation."

**Architecture:** Two view files changed. `_insights.html.erb` deleted and its content inlined into a rewritten `_results.html.erb`. Two additional files were patched during code quality review (see notes below).

**Tech Stack:** Rails 8.1.2, ERB, Tailwind CSS.

---

## Files Changed

| File | Change |
|---|---|
| `app/views/searches/_results.html.erb` | Full rewrite |
| `app/views/searches/_insights.html.erb` | Deleted |
| `app/presenters/search_results_presenter.rb` | Added `search_intent_id` public method |
| `app/views/searches/_low_confidence.html.erb` | Replaced `@search_run.search_intent_id` with `presenter.search_intent_id` |

---

## Notes on Deviations from Original Plan

Three code quality fixes were applied during review that differ from the plan's code snippet:

1. **`presenter.search_intent_id` (was `@search_run.search_intent_id`)** — Partials must not access controller instance variables directly. `search_intent_id` was added to `SearchResultsPresenter` and both `_results.html.erb` and `_low_confidence.html.erb` were updated.

2. **`bg-gray-100` on confidence badge (was `border`)** — The `border` class without an explicit border-color relied on `currentColor` accidentally. Replaced with `bg-gray-100` for a clean light-background pill.

3. **`t("insights.confidence.medium")` (was hardcoded `"Moderate confidence"`)** — The hardcoded string was inconsistent with the existing locale key. All three occurrences replaced with the i18n call.

---

### Task 1: Rewrite `_results.html.erb`

**Spec:** `docs/superpowers/specs/2026-03-23-results-page-hierarchy.md`

The new layout has three sections:
1. Slim page header (route + sample count + confidence badge + freshness)
2. Recommendation card hero (directive + subtext + AI summary + tags + date-range sub-grid)
3. Flights section ("The flights behind this recommendation" heading + flight cards)

**Files:**
- Modify: `app/views/searches/_results.html.erb`

- [x] **Step 1: Replace `_results.html.erb` with the new layout**

```erb
<div id="search_results" class="w-full">

  <%# ─── Section 1: Slim page header ─────────────────────────────────────── %>
  <div class="flex flex-wrap items-center justify-between gap-3 mb-6">
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-sm font-semibold text-gray-800"><%= presenter.origin %> &rarr; <%= presenter.destination %></span>
      <span class="text-xs text-gray-300">&middot;</span>
      <span class="text-xs text-gray-500"><%= presenter.sample_count %> <%= t("searches.show.options_analysed") %></span>
      <span class="text-xs font-semibold px-2 py-0.5 rounded-full bg-gray-100 <%= presenter.confidence_color_class %>">
        <%= presenter.confidence_label %>
      </span>
      <% if presenter.stale? %>
        <span class="text-xs text-gray-400"><%= presenter.freshness_label %></span>
        <%= link_to "Run again &rarr;".html_safe,
              new_search_path(from_intent: presenter.search_intent_id),
              class: "text-xs text-indigo-500 hover:text-indigo-600" %>
      <% else %>
        <span class="text-xs text-gray-400"><%= presenter.freshness_label %></span>
      <% end %>
    </div>
    <%= link_to new_search_path, class: "text-sm text-indigo-600 hover:text-indigo-700 font-medium" do %>
      <%= t("searches.show.search_again") %> &rarr;
    <% end %>
  </div>

  <%# ─── Section 2: Recommendation card (hero) ────────────────────────────── %>
  <%# Note: presenter.insights always returns an InsightsPresenter (never nil).
      insights.any? returns true if any of the four insight types is non-nil. %>
  <% insights = presenter.insights %>
  <% if (wob = insights.wait_or_book) %>
    <div class="rounded-2xl border-2 p-6 mb-8 <%= wob.directive_color_class %>">

      <%# a. Label + directive %>
      <p class="text-xs font-bold uppercase tracking-widest opacity-60 mb-1"><%= t("insights.recommendation_label") %></p>
      <h1 class="text-3xl font-extrabold tracking-tight mb-1"><%= wob.directive_label %></h1>
      <% if wob.subtext %>
        <p class="text-sm font-medium mb-5"><%= wob.subtext %></p>
      <% else %>
        <p class="text-sm font-medium mb-5">
          <%= wob.price_band_label %>
          <% if wob.top_price %> &middot; top options around <%= wob.top_price %><% end %>
        </p>
      <% end %>

      <%# b. AI route summary %>
      <% if insights.route_summary %>
        <div class="bg-white bg-opacity-40 rounded-xl px-4 py-3 mb-5">
          <p class="text-sm leading-relaxed"><%= insights.route_summary %></p>
        </div>
      <% end %>

      <%# c. Supporting tags row %>
      <div class="flex flex-wrap items-center gap-2 mb-6">
        <% if (rarity = insights.price_rarity) %>
          <span class="text-xs font-semibold px-2.5 py-1 rounded-full <%= rarity.badge_class %>">
            <%= rarity.label %>
          </span>
        <% end %>
        <% if wob.medium_confidence? %>
          <span class="text-xs font-semibold px-2.5 py-1 rounded-full bg-amber-100 text-amber-700">
            <%= t("insights.confidence.medium") %>
          </span>
        <% else %>
          <span class="text-xs font-semibold px-2.5 py-1 rounded-full <%= wob.directive_badge_class %>">
            <%= presenter.confidence_label %>
          </span>
        <% end %>
        <% if wob.top_price && wob.subtext %>
          <span class="text-xs font-semibold px-2.5 py-1 rounded-full bg-white bg-opacity-50">
            Typical fare: <%= wob.top_price %>
          </span>
        <% end %>
      </div>

      <%# d. Date-range insights (2-col sub-grid) %>
      <% btt = insights.best_time_to_travel %>
      <% ccw = insights.cheapest_comfort_window %>
      <% if btt || ccw %>
        <div class="grid <%= (btt && ccw) ? "grid-cols-1 sm:grid-cols-2" : "grid-cols-1" %> gap-3">

          <% if btt %>
            <div class="bg-white bg-opacity-50 rounded-xl p-4 text-indigo-900 border border-indigo-200 border-opacity-60">
              <div class="flex items-center justify-between gap-2 mb-2">
                <p class="text-xs font-bold uppercase tracking-wide opacity-60"><%= t("insights.best_time_label") %></p>
                <% if btt.medium_confidence? %>
                  <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-amber-100 text-amber-700"><%= t("insights.confidence.medium") %></span>
                <% end %>
              </div>
              <p class="text-base font-bold"><%= btt.date_range %></p>
              <% if btt.description %>
                <p class="mt-1 text-xs opacity-75"><%= btt.description %></p>
              <% end %>
              <p class="mt-1 text-xs opacity-60">
                Avg. score <%= btt.average_score %>/100 &middot;
                <%= btt.flight_count %> <%= "option".pluralize(btt.flight_count) %>
              </p>
              <% if btt.search_urls %>
                <div class="mt-3 pt-3 border-t border-indigo-200 border-opacity-40 flex items-center gap-3">
                  <span class="text-xs opacity-50"><%= t("flights.labels.search_this_flight") %></span>
                  <%= link_to t("flights.labels.google_flights"), btt.search_urls.google_flights_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-indigo-700 hover:underline" %>
                  <%= link_to t("flights.labels.skyscanner"), btt.search_urls.skyscanner_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-indigo-700 hover:underline" %>
                </div>
              <% end %>
            </div>
          <% end %>

          <% if ccw %>
            <div class="bg-white bg-opacity-50 rounded-xl p-4 text-purple-900 border border-purple-200 border-opacity-60">
              <div class="flex items-center justify-between gap-2 mb-2">
                <p class="text-xs font-bold uppercase tracking-wide opacity-60"><%= t("insights.best_value_label") %></p>
                <% if ccw.medium_confidence? %>
                  <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-amber-100 text-amber-700"><%= t("insights.confidence.medium") %></span>
                <% end %>
              </div>
              <p class="text-base font-bold"><%= ccw.date_range %></p>
              <% if ccw.description %>
                <p class="mt-1 text-xs opacity-75"><%= ccw.description %></p>
              <% end %>
              <p class="mt-1 text-xs opacity-60">
                Balances price and comfort &middot; avg. score <%= ccw.average_score %>/100
              </p>
              <% if ccw.search_urls %>
                <div class="mt-3 pt-3 border-t border-purple-200 border-opacity-40 flex items-center gap-3">
                  <span class="text-xs opacity-50"><%= t("flights.labels.search_this_flight") %></span>
                  <%= link_to t("flights.labels.google_flights"), ccw.search_urls.google_flights_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-purple-700 hover:underline" %>
                  <%= link_to t("flights.labels.skyscanner"), ccw.search_urls.skyscanner_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-purple-700 hover:underline" %>
                </div>
              <% end %>
            </div>
          <% end %>

        </div>
      <% end %>
    </div>

  <% elsif insights.any? %>
    <%# Fallback: wait_or_book nil but other insights present (should not occur at medium/high confidence) %>
    <div class="rounded-2xl border-2 border-gray-200 bg-gray-50 p-6 mb-8">
      <% if insights.route_summary %>
        <div class="bg-white rounded-xl px-4 py-3 mb-4">
          <p class="text-sm text-gray-700 leading-relaxed"><%= insights.route_summary %></p>
        </div>
      <% end %>
      <% btt = insights.best_time_to_travel %>
      <% ccw = insights.cheapest_comfort_window %>
      <% if btt || ccw %>
        <div class="grid <%= (btt && ccw) ? "grid-cols-1 sm:grid-cols-2" : "grid-cols-1" %> gap-3">
          <% if btt %>
            <div class="bg-white rounded-xl p-4 border border-gray-200">
              <p class="text-xs font-bold uppercase tracking-wide text-gray-400 mb-2"><%= t("insights.best_time_label") %></p>
              <p class="text-base font-bold text-gray-900"><%= btt.date_range %></p>
            </div>
          <% end %>
          <% if ccw %>
            <div class="bg-white rounded-xl p-4 border border-gray-200">
              <p class="text-xs font-bold uppercase tracking-wide text-gray-400 mb-2"><%= t("insights.best_value_label") %></p>
              <p class="text-base font-bold text-gray-900"><%= ccw.date_range %></p>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>

  <%# ─── Section 3: Flights section ───────────────────────────────────────── %>
  <div>
    <h2 class="text-sm font-semibold text-gray-500 mb-4">The flights behind this recommendation</h2>
    <div class="space-y-3">
      <% presenter.ranked_flights.each do |flight| %>
        <%= render "searches/flight_card", flight: flight %>
      <% end %>
    </div>
  </div>

</div>
```

- [x] **Step 2: Run existing request specs to verify nothing is broken**

```bash
bundle exec rspec spec/requests/searches_spec.rb --format documentation
```

Result: 35 examples, 0 failures.

- [ ] **Step 3: Visual smoke test** _(manual — skipped in automated run)_

Open a completed search result and verify the three-section layout renders correctly.

---

### Task 2: Delete `_insights.html.erb`

Its content is fully inlined into `_results.html.erb`. The partial is no longer referenced anywhere.

**Files:**
- Delete: `app/views/searches/_insights.html.erb`

- [x] **Step 1: Confirm no remaining references to the partial**

```bash
grep -r 'render.*searches/insights' app/views/ --include="*.erb"
```

Result: no output (zero matches).

- [x] **Step 2: Delete the file**

File deleted.

- [x] **Step 3: Run full test suite**

```bash
bundle exec rspec
```

Result: 614 examples, 9 pre-existing failures (StripeConfig missing env var, Amadeus missing credentials) — 0 new failures.

- [x] **Step 4: Run Rubocop**

```bash
bin/rubocop
```

Result: 5 pre-existing offenses in `spec/services/route_summary_copy_service_spec.rb` — 0 new offenses.
