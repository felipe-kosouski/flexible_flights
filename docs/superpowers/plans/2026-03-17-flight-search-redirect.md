# Flight Search Redirect Links — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pre-filled Google Flights and Skyscanner redirect links to each ranked flight card and to the best-time-to-travel / cheapest-comfort-window insight cards.

**Architecture:** A new pure-Ruby `FlightSearchUrlBuilder` class (in `app/presenters/`) encapsulates both URL formats and returns a frozen struct. `RankedFlightPresenter` and `InsightsPresenter::DateRangePresenter` call the builder using data already in scope — no new data flows are required except threading `origin`/`destination` into `InsightsPresenter`. Views conditionally render two links per entry point.

**Tech Stack:** Ruby on Rails 8.1, ERB, Tailwind CSS, RSpec.

**Spec:** `docs/superpowers/specs/2026-03-17-flight-search-redirect-design.md`

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `app/presenters/flight_search_url_builder.rb` | Builds Skyscanner + Google Flights URLs from route + dates |
| Create | `spec/presenters/flight_search_url_builder_spec.rb` | Full-URL assertions for both platforms |
| Modify | `app/presenters/ranked_flight_presenter.rb` | Add `search_urls` method |
| Create | `spec/presenters/ranked_flight_presenter_spec.rb` | Cover `search_urls` present/nil |
| Modify | `app/presenters/insights_presenter.rb` | Add `origin`/`destination` args; thread into `DateRangePresenter`; add `search_urls` |
| Create | `spec/presenters/insights_presenter_spec.rb` | Cover `DateRangePresenter#search_urls` present/nil |
| Modify | `app/presenters/search_results_presenter.rb` | Pass `origin:`/`destination:` to `InsightsPresenter` |
| Modify | `app/views/searches/_flight_card.html.erb` | Add search links row at bottom of each card |
| Modify | `app/views/searches/_insights.html.erb` | Add search links to BTT and CCW insight cards |

---

## Task 1: `FlightSearchUrlBuilder`

**Files:**
- Create: `app/presenters/flight_search_url_builder.rb`
- Create: `spec/presenters/flight_search_url_builder_spec.rb`

This class is pure Ruby — no Rails, no ActiveRecord. The spec uses `spec_helper` (not `rails_helper`) to confirm this.

- [ ] **Step 1: Write the failing spec**

`spec/presenters/flight_search_url_builder_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"
require_relative "../../app/presenters/flight_search_url_builder"

RSpec.describe FlightSearchUrlBuilder do
  let(:origin)         { "BCN" }
  let(:destination)    { "LHR" }
  let(:departure_date) { Date.new(2025, 5, 1) }
  let(:return_date)    { Date.new(2025, 5, 8) }

  subject(:urls) do
    described_class.call(
      origin:         origin,
      destination:    destination,
      departure_date: departure_date,
      return_date:    return_date
    )
  end

  describe "#skyscanner_url" do
    it "builds the full Skyscanner search URL with YYMMDD dates" do
      expect(urls.skyscanner_url).to eq(
        "https://www.skyscanner.com/transport/flights/BCN/LHR/250501/250508/?adults=1&cabinclass=economy"
      )
    end

    it "upcases IATA codes" do
      result = described_class.call(
        origin: "bcn", destination: "lhr",
        departure_date: departure_date, return_date: return_date
      )
      expect(result.skyscanner_url).to include("/BCN/LHR/")
    end
  end

  describe "#google_flights_url" do
    it "builds the full Google Flights fragment URL" do
      expect(urls.google_flights_url).to eq(
        "https://www.google.com/travel/flights#flt=BCN.LHR.2025-05-01*LHR.BCN.2025-05-08;c:EUR;e:1;sd:1;t:f"
      )
    end

    it "upcases IATA codes" do
      result = described_class.call(
        origin: "bcn", destination: "lhr",
        departure_date: departure_date, return_date: return_date
      )
      expect(result.google_flights_url).to include("BCN.LHR")
    end
  end

  describe "return value" do
    it "returns a FlightSearchUrls struct" do
      expect(urls).to be_a(FlightSearchUrls)
    end

    it "is frozen" do
      expect(urls).to be_frozen
    end
  end
end
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
bundle exec rspec spec/presenters/flight_search_url_builder_spec.rb
```

Expected: `LoadError` or `NameError` — file does not exist yet.

- [ ] **Step 3: Implement `FlightSearchUrlBuilder`**

`app/presenters/flight_search_url_builder.rb`:

```ruby
# frozen_string_literal: true

FlightSearchUrls = Struct.new(:google_flights_url, :skyscanner_url, keyword_init: true)

class FlightSearchUrlBuilder
  SKYSCANNER_BASE    = "https://www.skyscanner.com/transport/flights"
  GOOGLE_FLIGHTS_BASE = "https://www.google.com/travel/flights"

  CABIN_CLASS_STRINGS = {
    economy:  "economy",
    business: "business",
    first:    "first"
  }.freeze

  def self.call(origin:, destination:, departure_date:, return_date:, passengers: 1, cabin_class: :economy)
    new(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:).call
  end

  def initialize(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
    @origin         = origin.upcase
    @destination    = destination.upcase
    @departure_date = departure_date
    @return_date    = return_date
    @passengers     = passengers
    @cabin_class    = cabin_class
  end

  def call
    FlightSearchUrls.new(
      google_flights_url: build_google_flights_url,
      skyscanner_url:     build_skyscanner_url
    ).freeze
  end

  private

  def build_skyscanner_url
    depart = @departure_date.strftime("%y%m%d")
    ret    = @return_date.strftime("%y%m%d")
    cabin  = CABIN_CLASS_STRINGS.fetch(@cabin_class, "economy")

    "#{SKYSCANNER_BASE}/#{@origin}/#{@destination}/#{depart}/#{ret}/?adults=#{@passengers}&cabinclass=#{cabin}"
  end

  def build_google_flights_url
    depart = @departure_date.iso8601
    ret    = @return_date.iso8601

    "#{GOOGLE_FLIGHTS_BASE}#flt=#{@origin}.#{@destination}.#{depart}*#{@destination}.#{@origin}.#{ret};c:EUR;e:1;sd:1;t:f"
  end
end
```

- [ ] **Step 4: Run the spec and confirm it passes**

```bash
bundle exec rspec spec/presenters/flight_search_url_builder_spec.rb
```

Expected: all examples pass, 0 failures.

- [ ] **Step 5: Run the full suite to check for regressions**

```bash
bundle exec rspec
```

Expected: 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/presenters/flight_search_url_builder.rb spec/presenters/flight_search_url_builder_spec.rb
git commit -m "feat: add FlightSearchUrlBuilder for Google Flights and Skyscanner redirect URLs"
```

---

## Task 2: `RankedFlightPresenter#search_urls`

**Files:**
- Modify: `app/presenters/ranked_flight_presenter.rb`
- Create: `spec/presenters/ranked_flight_presenter_spec.rb`

The presenter already receives `intent:` (the AR `SearchIntent` object with `origin_airport` / `destination_airport`) and wraps a flight with `departure_datetime` / `return_datetime`. No new data flows in.

- [ ] **Step 1: Write the failing spec**

`spec/presenters/ranked_flight_presenter_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe RankedFlightPresenter do
  let(:departure_dt) { Time.zone.local(2025, 5, 1, 10, 0) }
  let(:return_dt)    { Time.zone.local(2025, 5, 8, 18, 0) }

  let(:flight) do
    instance_double(
      Search::Models::FlightSample,
      departure_datetime:    departure_dt,
      return_datetime:       return_dt,
      price_cents:           15000,
      stops:                 0,
      air_time_minutes:      120,
      layover_time_minutes:  0,
      luggage_included?:     false,
      stay_length_days:      7
    )
  end

  let(:score_result) do
    instance_double(
      Search::Scoring::ScoreResult,
      value: 82.0,
      components: { price: 80.0, time_comfort: 85.0, trip_fit: 80.0 }
    )
  end

  let(:ranked_flight) do
    instance_double(
      Search::Ranking::RankedFlight,
      rank:         1,
      flight:       flight,
      score_result: score_result,
      explanation:  nil
    )
  end

  let(:intent) do
    instance_double(
      SearchIntent,
      origin_airport:      "BCN",
      destination_airport: "LHR"
    )
  end

  describe "#search_urls" do
    context "when intent is present" do
      subject(:presenter) { described_class.new(ranked_flight, intent: intent) }

      it "returns a FlightSearchUrls struct" do
        expect(presenter.search_urls).to be_a(FlightSearchUrls)
      end

      it "builds a Skyscanner URL with the flight dates" do
        expect(presenter.search_urls.skyscanner_url).to include("BCN/LHR/250501/250508")
      end

      it "builds a Google Flights URL with the flight dates" do
        expect(presenter.search_urls.google_flights_url).to include("BCN.LHR.2025-05-01")
      end
    end

    context "when intent is absent" do
      subject(:presenter) { described_class.new(ranked_flight) }

      it "returns nil" do
        expect(presenter.search_urls).to be_nil
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
bundle exec rspec spec/presenters/ranked_flight_presenter_spec.rb
```

Expected: `NoMethodError: undefined method 'search_urls'`

- [ ] **Step 3: Add `search_urls` to `RankedFlightPresenter`**

In `app/presenters/ranked_flight_presenter.rb`, add after the `private` keyword boundary (before the existing private methods, keep it public):

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

Place this method in the public section, after `skip_reason` and before `price_score`.

- [ ] **Step 4: Run the spec and confirm it passes**

```bash
bundle exec rspec spec/presenters/ranked_flight_presenter_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Run the full suite**

```bash
bundle exec rspec
```

Expected: 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/presenters/ranked_flight_presenter.rb spec/presenters/ranked_flight_presenter_spec.rb
git commit -m "feat: add search_urls to RankedFlightPresenter"
```

---

## Task 3: `InsightsPresenter` + `DateRangePresenter#search_urls`

**Files:**
- Modify: `app/presenters/insights_presenter.rb`
- Create: `spec/presenters/insights_presenter_spec.rb`

`InsightsPresenter` gets two new keyword args (`origin:`, `destination:`) that are threaded into `DateRangePresenter` (the nested inner class). `DateRangePresenter` gains a `search_urls` method that uses `from_date` / `to_date` from the insight.

> **Important:** `DateRangePresenter` is a nested class — it is defined inside `InsightsPresenter`, i.e., `InsightsPresenter::DateRangePresenter`. Keep it nested.

- [ ] **Step 1: Write the failing spec**

`spec/presenters/insights_presenter_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsightsPresenter do
  let(:from_date)    { Date.new(2025, 5, 1) }
  let(:to_date)      { Date.new(2025, 5, 8) }

  let(:date_range_insight) do
    instance_double(
      Search::Insights::DateRangeInsight,
      from_date:      from_date,
      to_date:        to_date,
      average_score:  78.5,
      flight_count:   12,
      confidence_level: :high
    )
  end

  let(:insights) do
    instance_double(
      Search::Insights::SearchInsights,
      best_time_to_travel:     date_range_insight,
      cheapest_comfort_window: date_range_insight,
      wait_or_book:            nil,
      price_rarity:            nil,
      confidence_level:        :high
    )
  end

  describe "InsightsPresenter::DateRangePresenter#search_urls" do
    context "when origin and destination are provided" do
      subject(:presenter) do
        described_class.new(insights, origin: "BCN", destination: "LHR")
      end

      it "returns a FlightSearchUrls struct from best_time_to_travel" do
        expect(presenter.best_time_to_travel.search_urls).to be_a(FlightSearchUrls)
      end

      it "builds a Skyscanner URL with the insight date range" do
        expect(presenter.best_time_to_travel.search_urls.skyscanner_url)
          .to include("BCN/LHR/250501/250508")
      end

      it "builds a Google Flights URL with the insight date range" do
        expect(presenter.best_time_to_travel.search_urls.google_flights_url)
          .to include("BCN.LHR.2025-05-01")
      end

      it "also works for cheapest_comfort_window" do
        expect(presenter.cheapest_comfort_window.search_urls).to be_a(FlightSearchUrls)
      end
    end

    context "when origin and destination are absent" do
      subject(:presenter) { described_class.new(insights) }

      it "returns nil from best_time_to_travel" do
        expect(presenter.best_time_to_travel.search_urls).to be_nil
      end

      it "returns nil from cheapest_comfort_window" do
        expect(presenter.cheapest_comfort_window.search_urls).to be_nil
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
bundle exec rspec spec/presenters/insights_presenter_spec.rb
```

Expected: `ArgumentError` (unknown keyword) or `NoMethodError: search_urls`.

- [ ] **Step 3: Update `InsightsPresenter`**

In `app/presenters/insights_presenter.rb`:

**`initialize`** — add `origin:` and `destination:` keyword args:

```ruby
def initialize(insights, route_summary: nil, origin: nil, destination: nil)
  @insights     = insights
  @route_summary = route_summary
  @origin        = origin
  @destination   = destination
end
```

**`best_time_to_travel`** — pass origin/destination to `DateRangePresenter`:

```ruby
def best_time_to_travel
  return nil unless @insights.best_time_to_travel

  DateRangePresenter.new(@insights.best_time_to_travel, origin: @origin, destination: @destination)
end
```

**`cheapest_comfort_window`** — same:

```ruby
def cheapest_comfort_window
  return nil unless @insights.cheapest_comfort_window

  DateRangePresenter.new(@insights.cheapest_comfort_window, origin: @origin, destination: @destination)
end
```

**`DateRangePresenter` (nested class)** — update `initialize` and add `search_urls`:

```ruby
class DateRangePresenter
  def initialize(insight, origin: nil, destination: nil)
    @insight     = insight
    @origin      = origin
    @destination = destination
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

  # existing methods below — do not change them
  def date_range
    "#{@insight.from_date.strftime('%b %-d')} – #{@insight.to_date.strftime('%b %-d')}"
  end

  # ... rest unchanged
end
```

- [ ] **Step 4: Run the spec and confirm it passes**

```bash
bundle exec rspec spec/presenters/insights_presenter_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Run the full suite**

```bash
bundle exec rspec
```

Expected: 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/presenters/insights_presenter.rb spec/presenters/insights_presenter_spec.rb
git commit -m "feat: add search_urls to InsightsPresenter::DateRangePresenter"
```

---

## Task 4: Wire `SearchResultsPresenter`

**Files:**
- Modify: `app/presenters/search_results_presenter.rb`

One-line change: pass `origin:` and `destination:` to `InsightsPresenter`. Use the existing public `origin` and `destination` methods (which already normalise to uppercase), not the AR attributes directly.

No new spec is needed for this step. The existing `spec/presenters/search_results_presenter_spec.rb` already stubs `origin_airport: "JFK"` and `destination_airport: "LHR"` on the `search_intent` double. The `origin` and `destination` public methods delegate to those attributes — so after this change, `InsightsPresenter` will receive real values and the existing spec will exercise the new wiring automatically. The new keyword arguments (`origin:`, `destination:`) are validated in the `InsightsPresenter` spec written in Task 3.

- [ ] **Step 1: Update `SearchResultsPresenter#insights`**

Find the `insights` method in `app/presenters/search_results_presenter.rb` (currently line 22) and update it:

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

- [ ] **Step 2: Run the existing `SearchResultsPresenter` spec to confirm nothing broke**

```bash
bundle exec rspec spec/presenters/search_results_presenter_spec.rb
```

Expected: all examples pass.

- [ ] **Step 3: Run the full suite**

```bash
bundle exec rspec
```

Expected: 0 failures.

- [ ] **Step 4: Commit**

```bash
git add app/presenters/search_results_presenter.rb
git commit -m "feat: pass origin and destination to InsightsPresenter from SearchResultsPresenter"
```

---

## Task 5: View — Per-flight card links

**Files:**
- Modify: `app/views/searches/_flight_card.html.erb`

Add the search links row at the bottom of the card, inside the outer `<div>` but after the explanation block. The partial uses `flight` as the local variable (set by the caller).

- [ ] **Step 1: Add the links block to `_flight_card.html.erb`**

Open `app/views/searches/_flight_card.html.erb`. After the closing `<% end %>` of the explanation block (line 85), and before the closing `</div>` of the main info section (line 87), add:

```erb
      <%# Search redirect links %>
      <% if flight.search_urls %>
        <div class="mt-3 pt-3 border-t border-gray-100 flex items-center gap-4">
          <span class="text-xs text-gray-400">Search this flight:</span>
          <%= link_to "Google Flights", flight.search_urls.google_flights_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-blue-600 hover:text-blue-800 hover:underline" %>
          <%= link_to "Skyscanner", flight.search_urls.skyscanner_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-cyan-600 hover:text-cyan-800 hover:underline" %>
        </div>
      <% end %>
```

- [ ] **Step 2: Verify the full suite still passes**

```bash
bundle exec rspec
```

Expected: 0 failures.

- [ ] **Step 3: Commit**

```bash
git add app/views/searches/_flight_card.html.erb
git commit -m "feat: add search redirect links to ranked flight cards"
```

---

## Task 6: View — Insight card CTAs

**Files:**
- Modify: `app/views/searches/_insights.html.erb`

Add search links inside the `best_time_to_travel` and `cheapest_comfort_window` cards. Both use the `btt` and `ccw` local variables already established in the view.

- [ ] **Step 1: Add links to the "Best time to travel" card**

In `app/views/searches/_insights.html.erb`, find the `best_time_to_travel` block (around line 52–68). After the `<p class="mt-1 text-xs opacity-70">` avg. score line and before the closing `</div>`, add:

```erb
      <% if btt.search_urls %>
        <div class="mt-3 pt-3 border-t border-indigo-200 border-opacity-50 flex items-center gap-4">
          <span class="text-xs opacity-60">Search this window:</span>
          <%= link_to "Google Flights", btt.search_urls.google_flights_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-indigo-700 hover:text-indigo-900 hover:underline" %>
          <%= link_to "Skyscanner", btt.search_urls.skyscanner_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-indigo-700 hover:text-indigo-900 hover:underline" %>
        </div>
      <% end %>
```

- [ ] **Step 2: Add links to the "Best value window" (cheapest comfort) card**

In the same file, find the `cheapest_comfort_window` block (around line 71–87). After the `<p class="mt-1 text-xs opacity-70">` balances price/comfort line and before the closing `</div>`, add:

```erb
      <% if ccw.search_urls %>
        <div class="mt-3 pt-3 border-t border-purple-200 border-opacity-50 flex items-center gap-4">
          <span class="text-xs opacity-60">Search this window:</span>
          <%= link_to "Google Flights", ccw.search_urls.google_flights_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-purple-700 hover:text-purple-900 hover:underline" %>
          <%= link_to "Skyscanner", ccw.search_urls.skyscanner_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-purple-700 hover:text-purple-900 hover:underline" %>
        </div>
      <% end %>
```

- [ ] **Step 3: Run the full suite**

```bash
bundle exec rspec
```

Expected: 0 failures.

- [ ] **Step 4: Smoke test in development**

```bash
bin/dev
```

- Run a search, wait for results.
- Confirm each flight card shows "Search this flight: Google Flights | Skyscanner" at the bottom.
- Confirm the best-time and best-value insight cards show "Search this window" links.
- Click each link and verify it opens a pre-filled search on the correct platform in a new tab.

- [ ] **Step 5: Commit**

```bash
git add app/views/searches/_insights.html.erb
git commit -m "feat: add search redirect links to best-time and best-value insight cards"
```

---

## Done

All six tasks complete. The feature is live:

- `FlightSearchUrlBuilder` — pure Ruby, tested with full-URL assertions.
- Per-flight card — "Search this flight" with Google Flights + Skyscanner links.
- Insight cards (BTT + CCW) — "Search this window" with Google Flights + Skyscanner links.
- Future affiliate path documented in `docs/future/affiliate-deep-links.md`.
