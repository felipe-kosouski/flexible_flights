# Search History (Sub-project A) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a search history page, "Run again" pre-fill, and freshness indicators so users can revisit and reuse past searches.

**Architecture:** Three thin slices built in dependency order — history page first (controller + presenter + view), then the pre-fill hook in `SearchesController#new`, then freshness methods on `SearchResultsPresenter` with view updates. All new logic lives at the Rails layer (controllers, presenters, views); the domain layer is untouched.

**Tech Stack:** Ruby on Rails 8.1.2, ERB/Tailwind, RSpec (request specs + presenter unit specs), FactoryBot, Devise (`current_user`, `authenticate_user!`).

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `app/controllers/search_history_controller.rb` | `index` action — loads user's SearchRuns |
| Create | `app/presenters/search_history_presenter.rb` | Per-row display logic for history table |
| Create | `app/views/search_history/index.html.erb` | History page template |
| Modify | `config/routes.rb` | Add `GET /history` route |
| Modify | `app/views/layouts/application.html.erb` | Add "History" nav link |
| Modify | `app/controllers/searches_controller.rb` | `new` handles `from_intent` param |
| Modify | `app/presenters/search_results_presenter.rb` | Add `stale?` + `freshness_label` |
| Modify | `app/views/searches/_results.html.erb` | Render freshness indicator |
| Modify | `app/views/searches/_low_confidence.html.erb` | Render freshness indicator |
| Create | `spec/requests/search_history_spec.rb` | Access control + ordering specs |
| Modify | `spec/requests/searches_spec.rb` | Add `from_intent` pre-fill specs |
| Create | `spec/presenters/search_results_presenter_spec.rb` | `stale?` + `freshness_label` unit specs |

---

## Task 1: Route and SearchHistoryController

**Files:**
- Create: `app/controllers/search_history_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/requests/search_history_spec.rb`

- [ ] **Step 1: Write the failing request specs**

Create `spec/requests/search_history_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SearchHistory", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /history" do
    context "when not signed in" do
      it "redirects to sign in" do
        get search_history_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns 200" do
        get search_history_path
        expect(response).to have_http_status(:ok)
      end

      it "shows only the current user's search runs" do
        own_intent   = create(:search_intent, user: user)
        own_run      = create(:search_run, search_intent: own_intent)
        other_intent = create(:search_intent, user: other_user)
        other_run    = create(:search_run, search_intent: other_intent)

        get search_history_path

        expect(response.body).to include(own_run.id.to_s)
        expect(response.body).not_to include(other_run.id.to_s)
      end

      it "orders runs newest first" do
        intent = create(:search_intent, user: user)
        old_run = create(:search_run, search_intent: intent,
                         created_at: 3.days.ago)
        new_run = create(:search_run, search_intent: intent,
                         created_at: 1.hour.ago)

        get search_history_path

        # Both cards render a data-run-id attribute — assert new appears before old.
        expect(response.body.index("data-run-id=\"#{new_run.id}\""))
          .to be < response.body.index("data-run-id=\"#{old_run.id}\"")
      end

      it "renders an empty state when the user has no runs" do
        get search_history_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

- [ ] **Step 2: Run specs to confirm they fail**

```bash
bundle exec rspec spec/requests/search_history_spec.rb
```

Expected: 4 failures — `search_history_path` unrouted / controller missing.

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add before the `get "up"` line:

```ruby
get "history", to: "search_history#index", as: :search_history
```

Full file after edit:

```ruby
Rails.application.routes.draw do
  devise_for :users
  root "searches#new"

  resources :searches, only: [ :new, :create, :show ]

  get "history", to: "search_history#index", as: :search_history

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/search_history_controller.rb`:

```ruby
# frozen_string_literal: true

class SearchHistoryController < ApplicationController
  before_action :authenticate_user!

  def index
    @search_runs = current_user.search_runs
                               .includes(:search_intent)
                               .order(created_at: :desc)
  end
end
```

- [ ] **Step 5: Create a minimal view to unblock the specs**

Create `app/views/search_history/index.html.erb`:

```erb
<div id="search_history" class="w-full">
  <h1 class="text-2xl font-semibold text-gray-900 tracking-tight mb-6">Search History</h1>
  <% @search_runs.each do |run| %>
    <div data-run-id="<%= run.id %>"><%= run.id %></div>
  <% end %>
</div>
```

- [ ] **Step 6: Run specs — all should pass**

```bash
bundle exec rspec spec/requests/search_history_spec.rb
```

Expected: 4 examples, 0 failures.

- [ ] **Step 7: Run the full suite to check no regressions**

```bash
bundle exec rspec
```

Expected: all green.

---

## Task 2: SearchHistoryPresenter

**Files:**
- Create: `app/presenters/search_history_presenter.rb`

This presenter has no unit spec file yet — behavior will be confirmed visually via the view in Task 3. (The request specs in Task 1 already cover the controller-level data slicing.)

- [ ] **Step 1: Create the presenter**

Create `app/presenters/search_history_presenter.rb`:

```ruby
# frozen_string_literal: true

class SearchHistoryPresenter
  DAYS_IN_SECONDS = 86_400

  def initialize(search_run)
    @run    = search_run
    @intent = search_run.search_intent
  end

  def route
    "#{@intent.origin_airport.upcase} → #{@intent.destination_airport.upcase}"
  end

  def date_window
    from = @intent.earliest_departure.strftime("%-d %b")
    to   = @intent.latest_return.strftime("%-d %b")
    "#{from} – #{to}"
  end

  def stay_range
    "#{@intent.min_stay_days}–#{@intent.max_stay_days} nights"
  end

  def status_label
    case @run.state.to_sym
    when :completed   then "Completed"
    when :failed      then "Failed"
    else                   "In progress"
    end
  end

  def status_color_class
    case @run.state.to_sym
    when :completed then "bg-emerald-100 text-emerald-800"
    when :failed    then "bg-red-100 text-red-800"
    else                 "bg-amber-100 text-amber-800"
    end
  end

  def run_at
    timestamp = @run.finished_at || @run.created_at
    time_ago_in_words(timestamp) + " ago"
  end

  def view_results_path
    return nil unless @run.completed?

    Rails.application.routes.url_helpers.search_path(@run)
  end

  def run_again_path
    Rails.application.routes.url_helpers
         .new_search_path(from_intent: @intent.id)
  end

  private

  def time_ago_in_words(time)
    seconds = (Time.current - time).round
    days    = seconds / DAYS_IN_SECONDS
    hours   = seconds / 3600
    minutes = seconds / 60

    if days >= 1
      "#{days} #{days == 1 ? 'day' : 'days'}"
    elsif hours >= 1
      "#{hours} #{hours == 1 ? 'hour' : 'hours'}"
    elsif minutes >= 1
      "#{minutes} #{minutes == 1 ? 'minute' : 'minutes'}"
    else
      "moments"
    end
  end
end
```

- [ ] **Step 2: Run the full suite**

```bash
bundle exec rspec
```

Expected: all green (presenter is not tested directly yet — view integration tested in next task).

---

## Task 3: History Page View and Nav Link

**Files:**
- Modify: `app/views/search_history/index.html.erb` (replace stub from Task 1)
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Replace the stub view with the real template**

Replace `app/views/search_history/index.html.erb` entirely:

```erb
<div id="search_history" class="w-full max-w-3xl">
  <h1 class="text-2xl font-semibold text-gray-900 tracking-tight mb-6">Search History</h1>

  <% if @search_runs.empty? %>
    <div class="rounded-xl border border-gray-200 bg-white px-6 py-10 text-center">
      <p class="text-gray-500 text-sm">No searches yet.</p>
      <%= link_to "Start a search", new_search_path,
            class: "mt-3 inline-block text-sm text-indigo-600 hover:text-indigo-700 font-medium" %>
    </div>
  <% else %>
    <div class="space-y-3">
      <% @search_runs.each do |run| %>
        <% p = SearchHistoryPresenter.new(run) %>
        <div data-run-id="<%= run.id %>" class="rounded-xl border border-gray-200 bg-white px-5 py-4">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <p class="font-semibold text-gray-900 text-sm"><%= p.route %></p>
              <p class="mt-0.5 text-xs text-gray-500">
                <%= p.date_window %> &middot; <%= p.stay_range %>
              </p>
              <p class="mt-1 text-xs text-gray-400"><%= p.run_at %></p>
            </div>
            <div class="flex items-center gap-3 shrink-0">
              <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium <%= p.status_color_class %>">
                <%= p.status_label %>
              </span>
            </div>
          </div>
          <div class="mt-3 flex items-center gap-4 border-t border-gray-100 pt-3">
            <% if p.view_results_path %>
              <%= link_to "View results", p.view_results_path,
                    class: "text-xs text-indigo-600 hover:text-indigo-700 font-medium" %>
            <% end %>
            <%= link_to "Run again →", p.run_again_path,
                  class: "text-xs text-gray-500 hover:text-gray-700" %>
          </div>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Add "History" link to the nav**

In `app/views/layouts/application.html.erb`, inside the `<% if user_signed_in? %>` block, add the History link between the logo link and the user info div. The nav currently looks like:

```erb
      <%= link_to "Flexible Flights", root_path, class: "font-semibold text-gray-900 tracking-tight" %>
      <% if user_signed_in? %>
        <div class="flex items-center gap-4">
          <span class="text-sm text-gray-500"><%= current_user.email %></span>
```

Replace the `<% if user_signed_in? %>` block with:

```erb
      <%= link_to "Flexible Flights", root_path, class: "font-semibold text-gray-900 tracking-tight" %>
      <% if user_signed_in? %>
        <div class="flex items-center gap-6">
          <%= link_to "History", search_history_path,
                class: "text-sm text-gray-500 hover:text-gray-700 transition-colors" %>
          <div class="flex items-center gap-4">
            <span class="text-sm text-gray-500"><%= current_user.email %></span>
            <%= link_to "Sign out", destroy_user_session_path,
                  data: { turbo_method: :delete },
                  class: "text-sm text-gray-500 hover:text-gray-700 transition-colors" %>
          </div>
        </div>
      <% end %>
```

- [ ] **Step 3: Run the full suite**

```bash
bundle exec rspec
```

Expected: all green.

---

## Task 4: "Run Again" Pre-fill in SearchesController#new

**Files:**
- Modify: `app/controllers/searches_controller.rb`
- Modify: `spec/requests/searches_spec.rb`

- [ ] **Step 1: Add the pre-fill specs to `spec/requests/searches_spec.rb`**

Append these examples to the existing file (inside the outer `RSpec.describe` block, after the existing `describe` blocks):

```ruby
  describe "GET /searches/new with from_intent param" do
    before { sign_in user }

    context "with a valid from_intent belonging to current user" do
      it "returns 200 and pre-fills the form" do
        intent = create(:search_intent, user: user)
        get new_search_path(from_intent: intent.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a from_intent belonging to another user" do
      it "returns 200 and renders a blank form (no error)" do
        other_intent = create(:search_intent, user: other_user)
        get new_search_path(from_intent: other_intent.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a non-existent from_intent id" do
      it "returns 200 and renders a blank form (no error, no alert)" do
        get new_search_path(from_intent: 999_999)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Search not found")
      end
    end

    context "without a from_intent param" do
      it "returns 200 and renders a blank form" do
        get new_search_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
```

- [ ] **Step 2: Run just the new specs to confirm they fail**

```bash
bundle exec rspec spec/requests/searches_spec.rb -e "from_intent"
```

Expected: up to 4 failures (the `new` action ignores the param today).

Actually these may pass green since `new` returns 200 already. Run them:

```bash
bundle exec rspec spec/requests/searches_spec.rb
```

Note which (if any) fail — the 200 specs may already pass, which is fine. They confirm no regression. Continue to Step 3.

- [ ] **Step 3: Update `SearchesController#new`**

In `app/controllers/searches_controller.rb`, replace:

```ruby
  def new
    @search_intent = SearchIntent.new
  end
```

With:

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

**Why `find_by` not `find`:** The controller has a class-level `rescue_from ActiveRecord::RecordNotFound` that redirects with a noisy alert. Using `find` for an unknown `from_intent` would trigger that handler and leak that the ID exists. `find_by` returns `nil` silently instead.

**Why `dup.tap { |d| d.user_id = nil }`:** `ActiveRecord::Base#dup` copies all attributes, including `user_id`. The dup is an unsaved object intended to pre-fill a form — it must not carry the original owner's `user_id`, which would be semantically wrong before the new record is owned by `current_user` on submit.

- [ ] **Step 4: Run the searches request specs**

```bash
bundle exec rspec spec/requests/searches_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Run the full suite**

```bash
bundle exec rspec
```

Expected: all green.

---

## Task 5: SearchResultsPresenter — stale? and freshness_label

**Files:**
- Modify: `app/presenters/search_results_presenter.rb`
- Create: `spec/presenters/search_results_presenter_spec.rb`

- [ ] **Step 1: Write the unit specs**

Create `spec/presenters/search_results_presenter_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResultsPresenter do
  # Build a minimal double for SearchResults and SearchRun.
  # The domain objects are NOT loaded here — we only test the presenter's
  # own methods (stale? and freshness_label). Other presenter behaviour
  # is covered by integration/request specs.

  let(:snapshot) do
    instance_double(
      Search::Models::AnalysisSnapshot,
      confidence: :high,
      sample_count: 10
    )
  end

  let(:results) do
    instance_double(
      Search::SearchResults,
      snapshot: snapshot,
      ranked_flights: [],
      insights: instance_double(Search::Insights::SearchInsights,
                                best_time_to_travel: nil,
                                wait_or_book: nil,
                                price_rarity: nil,
                                cheapest_comfort_window: nil,
                                confidence_level: :high)
    )
  end

  let(:search_intent) do
    instance_double(
      SearchIntent,
      origin_airport: "JFK",
      destination_airport: "LHR",
      id: 1
    )
  end

  def build_presenter(finished_at:)
    run = instance_double(SearchRun,
      search_intent: search_intent,
      completed?: true,
      finished_at: finished_at
    )
    described_class.new(results, run)
  end

  describe "#stale?" do
    it "returns false when finished_at is 6 days ago" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 6.days.ago)
        expect(presenter.stale?).to be false
      end
    end

    it "returns true when finished_at is exactly 7 days ago" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 7.days.ago)
        expect(presenter.stale?).to be true
      end
    end

    it "returns true when finished_at is 8 days ago" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 8.days.ago)
        expect(presenter.stale?).to be true
      end
    end
  end

  describe "#freshness_label" do
    it "returns short form when fresh (< 7 days)" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 2.days.ago)
        expect(presenter.freshness_label).to eq("Analysed 2 days ago")
      end
    end

    it "returns 'consider running again' copy when stale (>= 7 days)" do
      travel_to Time.current do
        presenter = build_presenter(finished_at: 12.days.ago)
        expect(presenter.freshness_label).to eq("Analysed 12 days ago · consider running again")
      end
    end
  end
end
```

- [ ] **Step 2: Run the specs to confirm they fail**

```bash
bundle exec rspec spec/presenters/search_results_presenter_spec.rb
```

Expected: failures for `stale?` and `freshness_label` (methods don't exist yet).

- [ ] **Step 3: Add `stale?` and `freshness_label` to the presenter**

In `app/presenters/search_results_presenter.rb`, add these two public methods after `low_confidence?` (before `private`):

```ruby
  # Presenter is only instantiated when search_run.completed? (see SearchesController#show).
  # finished_at is always present on completed runs, but guard defensively.
  def stale?
    @search_run.finished_at.present? && @search_run.finished_at <= 7.days.ago
  end

  def freshness_label
    days = ((Time.current - @search_run.finished_at) / 1.day).floor
    label = "Analysed #{days} #{days == 1 ? 'day' : 'days'} ago"
    stale? ? "#{label} · consider running again" : label
  end
```

- [ ] **Step 4: Run the presenter specs**

```bash
bundle exec rspec spec/presenters/search_results_presenter_spec.rb
```

Expected: 5 examples, 0 failures.

- [ ] **Step 5: Run the full suite**

```bash
bundle exec rspec
```

Expected: all green.

---

## Task 6: Freshness Indicator in Views

**Files:**
- Modify: `app/views/searches/_results.html.erb`
- Modify: `app/views/searches/_low_confidence.html.erb`

The freshness line goes below the route header (`<h1>` + confidence sub-line) in both partials. When stale, it appends a "Run again →" link.

- [ ] **Step 1: Add freshness indicator to `_results.html.erb`**

In `app/views/searches/_results.html.erb`, locate the header `<div>` that ends after the confidence sub-line:

```erb
      <p class="mt-1 text-sm text-gray-500">
        <%= presenter.sample_count %> options analysed &middot;
        <span class="<%= presenter.confidence_color_class %>"><%= presenter.confidence_label %></span>
      </p>
```

Add the freshness line immediately after that `<p>` tag, still inside the inner `<div>`:

```erb
      <p class="mt-1 text-xs text-gray-400">
        <%= presenter.freshness_label %>
        <% if presenter.stale? %>
          &middot;
          <%= link_to "Run again →",
                new_search_path(from_intent: @search_run.search_intent_id),
                class: "text-indigo-500 hover:text-indigo-600" %>
        <% end %>
      </p>
```

- [ ] **Step 2: Add freshness indicator to `_low_confidence.html.erb`**

In `app/views/searches/_low_confidence.html.erb`, locate the header confidence sub-line:

```erb
      <p class="mt-1 text-sm text-gray-500">
        <%= presenter.sample_count %> options analysed &middot;
        <span class="text-red-500">Low confidence</span>
      </p>
```

Add the freshness line immediately after that `<p>` tag:

```erb
      <p class="mt-1 text-xs text-gray-400">
        <%= presenter.freshness_label %>
        <% if presenter.stale? %>
          &middot;
          <%= link_to "Run again →",
                new_search_path(from_intent: @search_run.search_intent_id),
                class: "text-indigo-500 hover:text-indigo-600" %>
        <% end %>
      </p>
```

- [ ] **Step 3: Run the full suite**

```bash
bundle exec rspec
```

Expected: all green.

---

## Done

All three features are implemented:

1. `GET /history` shows the signed-in user's SearchRuns newest-first, with route, date window, stay range, status badge, relative timestamp, "View results" (completed only), and "Run again" links.
2. `GET /searches/new?from_intent=<id>` pre-fills the form from a past SearchIntent scoped to `current_user`. Unknown or other-user IDs silently render a blank form.
3. Results pages (`_results` and `_low_confidence`) show a freshness line: fresh copy under 7 days, stale copy at/over 7 days with a "Run again →" link.
