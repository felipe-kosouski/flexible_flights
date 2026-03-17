# Flight Search Redirect Links — Design Spec

**Date:** 2026-03-17
**Status:** Approved

---

## Problem

After receiving a Smart Search result, users have no way to act on the recommendations. They get told "this is the best time to travel" or "this flight scores well" but must manually search elsewhere to find and book it. This friction erodes trust in the recommendations.

## Solution

Add pre-filled search redirect links to Google Flights and Skyscanner at two points in the results UI:

1. **Per-flight card** — links pre-filled with that flight's exact departure and return dates.
2. **Top-level CTA** — links in the `best_time_to_travel` and `cheapest_comfort_window` insight cards, pre-filled with the recommended date window.

Both links open in a new tab. This keeps Flexible Flights as the decision layer while handing off the booking transaction to established platforms.

---

## Scope

### In scope

- `FlightSearchUrlBuilder` — new pure-Ruby class that builds Google Flights and Skyscanner search URLs.
- `RankedFlightPresenter#search_urls` — exposes URLs per flight using the flight's specific dates.
- `InsightsPresenter` + `DateRangePresenter` — thread origin/destination through and expose `search_urls` on date-range insights.
- `SearchResultsPresenter` — pass origin/destination to `InsightsPresenter`.
- View changes — add link rows to flight cards and insight cards.
- `docs/future/affiliate-deep-links.md` — documents the path to affiliate and direct booking links.

### Out of scope

- Affiliate tracking parameters (future work — see future doc).
- Direct booking or booking flow.
- Per-flight deep links to a specific offer (requires re-querying provider; future work).

---

## Architecture

### `FlightSearchUrlBuilder`

**Location:** `app/presenters/flight_search_url_builder.rb`

Pure Ruby. No Rails or ActiveRecord dependencies. Encapsulates all URL-building logic for both platforms in a single place.

**Interface:**

```ruby
FlightSearchUrls = Struct.new(:google_flights_url, :skyscanner_url, keyword_init: true)

class FlightSearchUrlBuilder
  def self.call(origin:, destination:, departure_date:, return_date:, passengers: 1, cabin_class: :economy)
    # returns FlightSearchUrls
  end
end
```

**Inputs:**

| Param | Type | Source |
|---|---|---|
| `origin` | String (IATA) | `SearchIntent#origin_airport` |
| `destination` | String (IATA) | `SearchIntent#destination_airport` |
| `departure_date` | Date | `FlightSample#departure_datetime.to_date` or `DateRangeInsight#from_date` |
| `return_date` | Date | `FlightSample#return_datetime.to_date` or `DateRangeInsight#to_date` |
| `passengers` | Integer | Defaults to 1 for MVP |
| `cabin_class` | Symbol | Defaults to `:economy` for MVP |

**URL formats:**

*Skyscanner:*
```
https://www.skyscanner.com/transport/flights/{ORIG}/{DEST}/{YYMMDD}/{YYMMDD}/?adults={n}&cabinclass={class}
```
Dates in `YYMMDD` format (e.g. `250501`). Cabin class as string (`economy`, `business`, `first`).

*Google Flights:*
```
https://www.google.com/travel/flights#flt={ORIG}.{DEST}.{YYYY-MM-DD}*{DEST}.{ORIG}.{YYYY-MM-DD};c:EUR;e:1;sd:1;t:f
```
Where `e:1` = economy, `sd:1` = sort by departure. This is the fragment-based format supported by Google Flights for round-trip searches.

Both URL formats are private methods — callers never depend on the format, only on the struct interface. This means the format can be updated or extended (e.g. add affiliate params) without touching any presenter or view.

**Testing:** Pure Ruby spec. No mocks, no HTTP. Asserts the **full URL string** for both platforms — not just individual components — so that any format change is caught immediately. The Skyscanner URL format (`/transport/flights/{ORIG}/{DEST}/{YYMMDD}/{YYMMDD}/`) is empirically derived and not part of a documented public API contract; pinning the full URL in tests is the safety net against silent breakage.

---

### `RankedFlightPresenter` — addition

Add `search_urls` method. The presenter already receives `intent:` and wraps a flight with `departure_datetime` / `return_datetime`. No new data needs to flow in.

> **Note:** The `intent:` parameter here is the **ActiveRecord `SearchIntent` object** (passed from `SearchResultsPresenter#ranked_flights` via `@search_run.search_intent`), not the domain read model `Search::Models::SearchIntent`. The AR object exposes `origin_airport` and `destination_airport` directly. The domain model does not — do not reach for the domain object here.

All ranked flights are round-trip by product definition. `flight.departure_datetime` and `flight.return_datetime` are both guaranteed non-nil for any flight that reaches the ranked results — flights with nil datetimes are filtered out during sampling before they enter the scored/ranked pipeline.

```ruby
def search_urls
  return nil unless @intent

  FlightSearchUrlBuilder.call(
    origin:         @intent.origin_airport,
    destination:    @intent.destination_airport,
    departure_date: flight.departure_datetime.to_date,
    return_date:    flight.return_datetime.to_date
  )
end
```

Returns `nil` if intent is absent (defensive — intent is always present in normal flow).

---

### `InsightsPresenter` — addition

Add `origin:` and `destination:` keyword args. Thread them into `DateRangePresenter`.

```ruby
class InsightsPresenter
  def initialize(insights, route_summary: nil, origin: nil, destination: nil)
    @origin      = origin
    @destination = destination
    # ...
  end

  def best_time_to_travel
    return nil unless @insights.best_time_to_travel
    DateRangePresenter.new(@insights.best_time_to_travel, origin: @origin, destination: @destination)
  end

  def cheapest_comfort_window
    return nil unless @insights.cheapest_comfort_window
    DateRangePresenter.new(@insights.cheapest_comfort_window, origin: @origin, destination: @destination)
  end
end
```

`DateRangePresenter` gains `search_urls`:

```ruby
class DateRangePresenter
  def initialize(insight, origin: nil, destination: nil)
    @origin      = origin
    @destination = destination
    # ...
  end

  def search_urls
    return nil unless @origin && @destination

    FlightSearchUrlBuilder.call(
      origin:         @origin,
      destination:    @destination,
      departure_date: @insight.from_date,
      return_date:    @insight.to_date
    )
  end
end
```

---

### `SearchResultsPresenter` — addition

Pass origin/destination when building `InsightsPresenter`. Use the existing public `origin` and `destination` methods (which already call `.upcase`) rather than reading `search_intent` attributes directly:

```ruby
def insights
  @insights ||= InsightsPresenter.new(
    @results.insights,
    route_summary: route_ai_summary,
    origin:        origin,
    destination:   destination
  )
end
```

No change to the existing `SearchResultsPresenter` spec is required — the test doubles for `search_intent` already return `origin_airport` and `destination_airport`, and the existing public `origin`/`destination` methods delegate to them.

> **Note:** `DateRangePresenter` is a nested class inside `InsightsPresenter` (`InsightsPresenter::DateRangePresenter`). The spec snippets show `class DateRangePresenter` for brevity — the actual implementation must keep it nested.

---

### View changes

**Per-flight card:**

At the bottom of each ranked flight card, conditionally render a link row when `search_urls` is present:

```erb
<% if presenter.search_urls %>
  <div class="flex gap-3 pt-2 border-t border-gray-100">
    <%= link_to "Google Flights", presenter.search_urls.google_flights_url,
          target: "_blank", rel: "noopener noreferrer", class: "..." %>
    <%= link_to "Skyscanner", presenter.search_urls.skyscanner_url,
          target: "_blank", rel: "noopener noreferrer", class: "..." %>
  </div>
<% end %>
```

**Insight cards (`best_time_to_travel`, `cheapest_comfort_window`):**

Inside each `DateRangePresenter`-backed card, conditionally render a "Search this window" CTA:

```erb
<% if presenter.search_urls %>
  <div class="flex gap-3 mt-3">
    <%= link_to "Google Flights", presenter.search_urls.google_flights_url,
          target: "_blank", rel: "noopener noreferrer", class: "..." %>
    <%= link_to "Skyscanner", presenter.search_urls.skyscanner_url,
          target: "_blank", rel: "noopener noreferrer", class: "..." %>
  </div>
<% end %>
```

---

## Data Flow

```
SearchResultsPresenter
  → RankedFlightPresenter(intent:)
      → FlightSearchUrlBuilder(origin, destination, departure_date, return_date)
          → FlightSearchUrls{ google_flights_url, skyscanner_url }

SearchResultsPresenter
  → InsightsPresenter(origin:, destination:)
      → DateRangePresenter(origin:, destination:, insight:)
          → FlightSearchUrlBuilder(origin, destination, from_date, to_date)
              → FlightSearchUrls{ google_flights_url, skyscanner_url }
```

---

## Testing

| File | What it covers |
|---|---|
| `spec/presenters/flight_search_url_builder_spec.rb` | URL shape, date encoding, IATA codes, cabin class mapping. Pure Ruby. |
| `spec/presenters/ranked_flight_presenter_spec.rb` | `search_urls` present with intent, nil without intent. |
| `spec/presenters/insights_presenter_spec.rb` | `DateRangePresenter#search_urls` present with origin/destination, nil without. |

No view specs. Links are conditional on `search_urls` presence — covered by presenter specs.

---

## Implementation Order

1. `FlightSearchUrlBuilder` + spec
2. `RankedFlightPresenter#search_urls` + spec update
3. `InsightsPresenter` + `DateRangePresenter` changes + spec update
4. `SearchResultsPresenter` change (one line)
5. View — flight card links
6. View — insight card CTAs
