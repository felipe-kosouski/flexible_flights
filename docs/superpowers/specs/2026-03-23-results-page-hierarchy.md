# Results Page Hierarchy — Design Spec (2026-03-23)

## Overview

Restructure the completed search results page so that insights are the unambiguous hero and flights are explicitly framed as supporting evidence. The current layout renders insights and flights at equal visual weight; this redesign makes the recommendation card the first and dominant element the user sees.

**Goal:** A user who lands on results should immediately understand what to do (book / wait / consider) before they ever scroll to the flight list.

---

## Decisions Made

| Question                   | Choice                                          |
| -------------------------- | ----------------------------------------------- |
| Overall layout             | Unified recommendation card (single hero block) |
| Flights section framing    | "The flights behind this recommendation"        |
| AI route summary placement | Inside the recommendation card                  |

---

## Page Structure

The results page (`_results.html.erb`) has four vertical sections in this order:

```
1. Page header      — slim, no visual weight
2. Recommendation card  — hero, full-width
3. Flights section  — secondary, framed as evidence
```

The `_low_confidence.html.erb` partial is out of scope — it deliberately withholds the recommendation and shows flights directly.

---

## Section 1 — Page Header

**Current:** Route heading + sample count + confidence label + freshness label, all in a block.

**New:** Slim single row. Left side: route (`GRU → LIS`). Right side: sample count + confidence badge + freshness label (if stale). No `<h1>` — the recommendation card provides the page's primary heading.

Purpose: orient the user with minimal visual weight so the recommendation card gets immediate attention.

---

## Section 2 — Recommendation Card (Hero)

A single full-width card that unifies all intelligence into one block. Color-coded by directive (same palette as today):

- `book_now` → emerald gradient
- `consider_booking` → yellow gradient
- `wait` → blue gradient
- `insufficient_data` → gray gradient (edge case; insights suppressed at low confidence so this rarely shows)

### Card anatomy (top to bottom)

**a. Label + directive**

- Small uppercase label: "Our recommendation"
- Large bold directive: "Book Now" / "Wait" / "Consider Booking"
- One-line supporting reason: render `WaitOrBookPresenter#subtext` if present; fall back to `wob.price_band_label` + `wob.top_price` (e.g. "Median fare: $680") if `subtext` is nil

**b. AI route summary**

- Frosted / semi-transparent inner box
- `InsightsPresenter#route_summary` prose (2–3 sentences)
- Only rendered if `route_summary` is present (it can be nil if the AI call fails)

**c. Supporting tags row**

- Pill badges: price rarity label, confidence level label (`presenter.confidence_label`), typical fare (`WaitOrBookPresenter#top_price`)
- Price rarity pill color uses `insights.price_rarity.badge_class` (not `color_class` — `badge_class` is the pill-scoped class; `color_class` is the card-level background)
- The `medium_confidence?` amber badge that previously appeared inside individual insight cards is absorbed here: if `insights.wait_or_book.medium_confidence?` is true, render the confidence pill in amber rather than the directive color
- Omit price rarity pill if `insights.price_rarity` is nil; omit typical fare pill if `wob.top_price` is nil

**d. Date-range insights (2-column sub-grid)**

- Left: Best time to travel (`DateRangePresenter` — date range, avg score, flight count, search links)
- Right: Cheapest comfort window (`DateRangePresenter` — same fields)
- Search links: render `btt.search_urls` links only if `btt.search_urls` is present (it can be nil if origin/destination are missing, though in practice `InsightsPresenter` is always initialized with both)
- `medium_confidence?` on date-range presenters: render a small amber "Moderate confidence" sub-label inside the sub-card if true
- Only rendered if each insight is present; if only one is present it spans full width
- If neither is present, the sub-grid is omitted entirely

### What moves out of the card

`PriceRarityPresenter` data (label, market price) is absorbed into the supporting tags row (c) rather than being a standalone card. The standalone price rarity card is removed.

---

## Section 3 — Flights Section

**Heading:** "The flights behind this recommendation" (hardcoded string, not i18n for now — can be extracted later).

**Flight cards:** Unchanged in structure and content. The `_flight_card.html.erb` partial requires no modification.

**Visual weight:** The heading is `text-sm font-semibold text-gray-500` — deliberately understated to reinforce the secondary role. Flight cards remain at full width with existing styling.

---

## Files Changed

| File                                    | Change                                                |
| --------------------------------------- | ----------------------------------------------------- |
| `app/views/searches/_results.html.erb`  | Full rewrite — new 3-section layout                   |
| `app/views/searches/_insights.html.erb` | Replaced by content now inline in `_results.html.erb` |

`_insights.html.erb` is deleted. Its content is inlined into `_results.html.erb` because the recommendation card is not a reusable component — it is the results page layout itself. Keeping a separate partial adds indirection with no benefit.

All other files (`_flight_card.html.erb`, `_loading.html.erb`, `_failed.html.erb`, `_low_confidence.html.erb`, all presenter files) are **unchanged**.

---

## Presenter Interface (no changes required)

The redesign reads only data already exposed by existing presenters:

| Data                                 | Source                                                                               |
| ------------------------------------ | ------------------------------------------------------------------------------------ |
| Directive label                      | `insights.wait_or_book.directive_label`                                              |
| Directive subtext (with fallback)    | `insights.wait_or_book.subtext` → fallback: `wob.price_band_label` + `wob.top_price` |
| Directive card/badge color           | `insights.wait_or_book.directive_color_class` / `directive_badge_class`              |
| Price rarity label                   | `insights.price_rarity.label`                                                        |
| Price rarity pill color              | `insights.price_rarity.badge_class` (not `color_class`)                              |
| Typical fare pill                    | `insights.wait_or_book.top_price`                                                    |
| Confidence pill label                | `presenter.confidence_label` (human-readable, from `SearchResultsPresenter`)         |
| Confidence pill color                | `presenter.confidence_color_class`                                                   |
| Medium confidence flag (wob)         | `insights.wait_or_book.medium_confidence?`                                           |
| Medium confidence flag (date ranges) | `btt.medium_confidence?` / `ccw.medium_confidence?`                                  |
| Route summary                        | `insights.route_summary`                                                             |
| Best time to travel                  | `insights.best_time_to_travel` (DateRangePresenter)                                  |
| Comfort window                       | `insights.cheapest_comfort_window` (DateRangePresenter)                              |
| Search links (date ranges)           | `btt.search_urls` / `ccw.search_urls` — render only if present                       |
| Ranked flights                       | `presenter.ranked_flights`                                                           |
| Origin / destination                 | `presenter.origin` / `presenter.destination`                                         |
| Sample count                         | `presenter.sample_count`                                                             |
| Stale?                               | `presenter.stale?` / `presenter.freshness_label`                                     |

No presenter changes are required.

---

## Edge Cases

| Case                                                 | Handling                                                                                                                      |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `route_summary` is nil                               | Skip the frosted summary box; card renders without it                                                                         |
| `price_rarity` is nil                                | Omit price rarity pill from the tags row                                                                                      |
| `best_time_to_travel` is nil, comfort window present | Comfort window spans full 2-col width                                                                                         |
| Both date-range insights nil                         | Sub-grid omitted; card ends after the tags row                                                                                |
| `wait_or_book` is nil                                | Should not occur at high/medium confidence, but if so: render a neutral gray card with just the route summary and date ranges |

---

## Out of Scope

- `_low_confidence.html.erb` — no change (separate render path; deliberately shows flights without a recommendation)
- `_loading.html.erb` — no change
- `_failed.html.erb` — no change
- All presenter files — no change
- The `low_confidence?` inline placeholder block in `_insights.html.erb` (lines that render "We need more data…" inside the insight grid when `insights.low_confidence?` is true) — this block is **dropped** in the new layout. The low-confidence render path is handled entirely by `_low_confidence.html.erb` at the `show.html.erb` level; `_results.html.erb` is only ever rendered at medium/high confidence
- i18n extraction of the new section heading — can be done in a follow-up
- Mobile layout — Tailwind's responsive classes handle stacking naturally; no special mobile design required
