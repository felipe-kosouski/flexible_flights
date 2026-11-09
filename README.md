<p align="center">
  <img src="public/logo.svg" alt="Flexible Flights" width="72" />
</p>

<h1 align="center">Flexible Flights</h1>

<p align="center">
  <strong>Decision intelligence for flexible travelers.</strong><br/>
  Not another flight search engine. An advisor that answers two questions:<br/>
  <em>When is the best time to travel?</em> and <em>Should I book now or wait?</em>
</p>

<p align="center">
  Ruby 4.0.1 · Rails 8.1.2 · PostgreSQL · Hotwire · Tailwind v4 · Solid Queue / Cache / Cable · Stripe · Claude Haiku
</p>

---

## Table of contents

- [What it is](#what-it-is)
- [How a Smart Search works](#how-a-smart-search-works)
- [Architecture](#architecture)
- [The domain pipeline](#the-domain-pipeline)
- [Scoring model](#scoring-model)
- [Confidence and insights](#confidence-and-insights)
- [Flight providers](#flight-providers)
- [Presentation and AI copy](#presentation-and-ai-copy)
- [Accounts, credits and payments](#accounts-credits-and-payments)
- [Getting started](#getting-started)
- [Configuration (credentials)](#configuration-credentials)
- [Testing and quality](#testing-and-quality)
- [Project layout](#project-layout)
- [Documentation map](#documentation-map)
- [Roadmap and status](#roadmap-and-status)
- [Known gaps](#known-gaps)
- [Contributing rules](#contributing-rules)

---

## What it is

Flexible Flights is a paid **decision-intelligence SaaS** for people whose travel dates can move: digital nomads, remote workers, flexible couples and families, retirees. Instead of listing the cheapest fare for one date, it samples the market across a whole date window, builds route-relative statistics, scores each option, and produces a confidence-gated recommendation in plain language.

**The paid unit is one Smart Search**: one route, one flexible date window, one stay-length range, one full analysis run. Every Smart Search delivers:

| Deliverable | What the user gets |
| --- | --- |
| **Best time to travel** | A concrete departure date range, with market-relative price context |
| **Book vs. wait** | A deterministic, confidence-gated directive: `book_now`, `consider_booking`, `wait`, or `insufficient_data` |
| **Price rarity** | Whether today's prices are rare, below the median, above it, or expensive *for this route* |
| **Cheapest comfort window** | Dates where price and comfort are both strong |
| **Ranked flights** | Comfort-aware, scored 0–100, each with a plain-language explanation and tradeoffs |

### What it deliberately is not

From [`docs/PRODUCT_GUIDE.md`](docs/PRODUCT_GUIDE.md), the product's single source of truth:

- ❌ No booking or checkout. Flights link out to Google Flights and Skyscanner.
- ❌ No price guarantees, and no predictions without a confidence level.
- ❌ No continuous monitoring or alerts (yet), and no subscriptions (yet).
- ❌ No ML price prediction or preference learning. Everything is deterministic and explainable.
- ✅ "We don't know" is a valid outcome. Low confidence suppresses advice instead of guessing.

**UX principles:** answers come before results · every recommendation is explainable · plain language, no jargon · paid value is insight, not more filters.

---

## How a Smart Search works

```
User fills the search form          (origin, destination, date window, stay range, luggage, max stops)
        │
        ▼
SearchesController#create           checks credits → saves SearchIntent → creates SearchRun → enqueues job
        │                           redirects to /searches/:id (loading state, subscribed via Turbo Stream)
        ▼
SearchRunJob  (Solid Queue)         resolves provider by name → SearchRunRepository.execute
        │
        ▼
Domain pipeline (pure Ruby)         sample → map → analyze → score → explain → rank → insights
        │
        ▼
Persist raw facts                   flight_samples + analysis_snapshot (inside one transaction)
        │
        ▼
Decrement 1 credit, then broadcast  Turbo Stream replaces the loading state with
                                    results / low-confidence / failed partial (via Solid Cable)
```

Only **raw facts** are persisted: flight samples and the market snapshot. Scores, explanations, rankings and insights are **recomputed on every read** by `SearchRunRepository.load_results`. The compute phases are pure Ruby and take microseconds, so raw data stays the source of truth and scoring changes apply retroactively to old searches.

---

## Architecture

A **modular monolith** with a rich, framework-free domain layer. Dependencies only flow downward:

```
Controllers / Jobs
    ↓
Repositories      the only place transactions open, domain execution is triggered, persistence is coordinated
    ↓
Domain layer      pure Ruby. No ActiveRecord, no Rails APIs, no I/O, no side effects
    ↓
ActiveRecord      validations and associations only. Stores facts, never decisions
```

Around that core:

| Layer | Location | Role |
| --- | --- | --- |
| **Domain** | `app/domain/search/` | All business logic: sampling, analysis, scoring, explanation, ranking, insights |
| **Adapters** | `app/domain/search/{factories,mappers,repositories}` | Factory (AR → domain), Mapper (domain → AR), Repository (transactions + orchestration) |
| **Providers** | `app/providers/flights/` | HTTP adapters to flight APIs, injected into the domain at the job boundary |
| **Presenters** | `app/presenters/` | View-model formatting, curated flight selection, external search URLs |
| **Services** | `app/services/` | AI-generated copy (Claude Haiku), outside the domain on purpose |
| **Support** | `app/support/` | Locale, currency, price formatting, Stripe config |

### Non-negotiable rules

- The domain **never** uses ActiveRecord or Rails, never touches the DB or network, never calls repositories, and knows nothing about jobs or controllers. Breaking this is an architectural bug, not a style issue.
- Factories and mappers are strictly one-way and side-effect free.
- Repositories return domain objects, never AR records.
- State transitions are explicit. Terminal states (`completed`, `failed`) cannot be exited.
- Given identical inputs, domain outputs and ordering are identical. No randomness.
- On failure the transaction rolls back (no partial samples), the `failed` state is persisted **outside** the transaction, and the error is re-raised so Solid Queue records it.

**Authority hierarchy** when sources disagree: `.cursor/rules/architecture.mdc` → `docs/domain/**` → `docs/PRD.md` → implementation. `docs/PRODUCT_GUIDE.md` governs product behavior.

---

## The domain pipeline

`Search::SearchExecution` runs eight explicit phases:

```
initialized → sampling → mapping → analyzing → scoring → explaining → ranking → insights → completed
                                                                                       ↘ failed
```

| Phase | Component | What it does |
| --- | --- | --- |
| **Sampling** | `Sampling::DateGrid` | Every `(departure, return)` pair in the window that satisfies the stay range |
| | `Sampling::CandidateSelector` | Caps pairs at `max_candidates` (default **20**), spreading slots evenly across departure dates |
| | `Sampling::Sampler` | Calls `provider.search` per pair, validates the 8 canonical fields, dedups identical offers |
| **Mapping** | `Mappers::FlightSampleMapper` | Raw hashes → immutable `Models::FlightSample` |
| **Analyzing** | `Analysis::SnapshotBuilder` | p25 / p50 / p75 prices, median effective duration, volatility, confidence |
| **Scoring** | `Scoring::Scorer` → `FinalScore` | Price + time comfort + trip fit → 0–100 `ScoreResult` with visible components |
| **Explaining** | `Explanation::Builder` | Score breakdown, baseline deviations, detected tradeoffs, deterministic summary |
| **Ranking** | `Ranking::Ranker` | Score DESC → price ASC → stops ASC → total duration ASC |
| **Insights** | `Insights::Builder` | The four insight artifacts, all confidence-gated |

---

## Scoring model

All scores are normalized 0–100 and **never hidden inside each other**. The UI shows each component.

```
final_score = 0.45 × price  +  0.35 × time_comfort  +  0.20 × trip_fit
```

If a component can't be computed, the remaining weights are re-normalized. A flight that fails a hard trip constraint gets no score and is dropped from ranking.

### Price score (route-relative)

| Price vs. this route's distribution | Score |
| --- | --- |
| ≤ p25 (cheap) | 100 |
| ≤ p50 (below median) | 80 |
| ≤ p75 (above median) | 50 |
| > p75 (expensive) | 20 |

Prices are only ever compared within the same route and search. Never across routes.

### Time comfort score

`0.6 × stops_score + 0.4 × duration_score`

- **Stops:** 0 → 100, 1 → 80, 2 → 50, 3+ → 20
- **Duration:** `effective_duration = air_time + layover_time × 1.3`, divided by the route median. ≤ 0.9× → 100, ≤ 1.1× → 80, ≤ 1.3× → 50, otherwise 20.

### Trip fit score

`(0.5 × length_fit + 0.3 × luggage_fit + 0.2 × time_fit) × 100`

- **Length fit** (dominant): 1.0 at the midpoint of the stay range, 0.9 near it, 0.7 elsewhere inside the range, 0.4 up to 3 days outside it. Further away is a hard fail.
- **Luggage fit:** required luggage missing is a hard fail. Optional luggage missing scores 0.8.
- **Time fit:** penalizes red-eye departures (before 06:00) and very late arrivals (after 23:00).

---

## Confidence and insights

### Market snapshot

| Signal | Rule |
| --- | --- |
| **Volatility** | `(p75 − p25) / p50`: ≤ 0.20 → `low`, ≤ 0.40 → `medium`, otherwise `high` |
| **Confidence** | < 10 samples → `low` · high volatility → `low` · ≥ 20 samples and low volatility → `high` · otherwise `medium` |

The lowest factor wins. **Low confidence means no strong advice:** best-time, price-rarity and comfort-window insights are suppressed, and book/wait returns `:insufficient_data`. The UI renders a dedicated low-confidence state instead of results.

### Book vs. wait

Based on the median price of the top 3 ranked flights, placed in the route's price bands:

| Condition | Directive |
| --- | --- |
| High volatility | `wait` |
| High confidence and cheap band | `book_now` |
| Medium confidence and cheap or below-median band | `consider_booking` |
| High confidence and below-median band | `consider_booking` |
| Anything else | `wait` |

### Other insights

- **Best time to travel:** groups ranked flights by ISO week (weeks with at least 2 flights) and picks the week with the highest average score.
- **Price rarity:** classifies the median of all ranked prices as `rare_cheap`, `below_median`, `above_median` or `expensive`.
- **Cheapest comfort window:** the date span of flights scoring ≥ 70 on both price and comfort (needs at least 2).

Results older than 7 days are labeled stale in the UI.

---

## Flight providers

Providers live outside the domain in `app/providers/flights/`. The domain only knows one method signature:

```ruby
provider.search(origin:, destination:, departure_date:, return_date:,
                passengers:, cabin_class:, currency_code: "USD")
# => Array<Hash> with: price_cents, currency, airline_codes, stops,
#    air_time_minutes, layover_time_minutes, luggage_included, raw_provider
```

| Provider | Key | Notes |
| --- | --- | --- |
| `Flights::Stub` | `"stub"` | Deterministic, returns two fixed offers. The default when no provider is configured |
| `Flights::Amadeus::Provider` | `"amadeus"` | Faraday client with OAuth2 token caching (60 s refresh buffer), typed error mapping, and a pure normalizer. Uses the test endpoint outside production |
| FlightAPI.io | `"flightapi"` | **Planned:** see `docs/superpowers/plans/2026-04-10-flightapi-provider.md` |

Providers are resolved by name through `Flights::Registry`, so jobs serialize a string rather than a Ruby object. Errors are mapped to `Flights::TimeoutError`, `RateLimitError`, `AuthError`, `InvalidResponse` (all `Flights::Error`).

**Adding a provider:** create `client.rb`, `normalizer.rb` and `provider.rb` under `app/providers/flights/<name>/` (provider subclasses `Flights::Base`), register it in `Registry::PROVIDERS`, and set `flight_provider: <name>` in credentials. No domain, repository or job changes needed. Specs must never make live HTTP calls (WebMock).

---

## Presentation and AI copy

- **Hotwire:** Turbo Streams over Solid Cable push results from the worker process into the open results page. Stimulus controllers handle airport autocomplete, theme toggle and the credits dropdown.
- **Results hierarchy:** the recommendation card is the hero (color-coded by directive, with an AI route summary, rarity and confidence tags, and best-time and comfort-window sub-cards). Flights come below as "the flights behind this recommendation."
- **Curated flights:** `SearchResultsPresenter` shows the top 3 plus the best-price and best-comfort picks, tagged with roles.
- **AI copy (Claude Haiku 4.5)**, in `app/services/`:
  - `RouteSummaryCopyService`: a 2–3 sentence route narrative. Skipped at low confidence, hedged at medium.
  - `ExplanationCopyService`: per-flight summaries, tradeoffs and an optional `skip_reason`, batched into one API call.
  - Both use **only the numbers they are given**, cache for 7 days, honor the user's locale, and fail silently, falling back to the deterministic domain explanation.
- **External links:** `FlightSearchUrlBuilder` builds prefilled Google Flights and Skyscanner URLs.
- **i18n:** English and Brazilian Portuguese. Locale is resolved from user preference, then session, then `Accept-Language`. Currency follows locale (USD / BRL).
- **Airport autocomplete:** client-side, about 4,500 large and medium airports with IATA codes, generated from `airports.csv` by `bin/rails airports:build`.
- **Design system:** deep teal brand (`#0D4A62`), amber CTA, Space Grotesk + DM Sans, light and dark modes, WCAG-minded focus rings and 44 px touch targets. See [`docs/design-system.md`](docs/design-system.md).

---

## Accounts, credits and payments

- **Auth:** Devise with `:confirmable`. New users must confirm their email, then receive a welcome email.
- **Free trial:** each account starts with **1 search credit** (enforced by a DB `CHECK (search_credits >= 0)`).
- **Gate:** `SearchesController#create` redirects to pricing at 0 credits. A credit is deducted **only after a search completes successfully**.
- **Credit packs:** 5 / 15 / 30 searches via hosted Stripe Checkout, priced in USD or BRL by locale.
- **Fulfillment:** the `checkout.session.completed` webhook (`POST /stripe/webhooks`) verifies the signature, records a `CreditPurchase`, and atomically increments credits. A unique index on `stripe_session_id` makes it idempotent.
- **Rate limiting** (`rack-attack`, Solid Cache backed):

  | Rule | Limit |
  | --- | --- |
  | Login by IP | 10 / 20 s |
  | Login by email | 5 / 20 s |
  | Signup by IP | 5 / 60 s |
  | Search creation by user | 3 / 60 s |

- **Other pages:** landing page (signed-in users go straight to search), search history with "search again" prefill, and a profile page for name, locale and account deletion.

---

## Getting started

### Prerequisites

- Ruby **4.0.1** (see `.ruby-version`)
- Docker (for PostgreSQL 16), or a local Postgres
- Bundler

### Setup

```bash
# 1. Start Postgres (host port 5434)
docker compose up -d db

# 2. Install gems, prepare the database
bin/setup --skip-server        # or: bundle install && bin/rails db:prepare

# 3. Add development credentials (see next section)
bin/rails credentials:edit --environment development

# 4. Run web + Tailwind watcher + Solid Queue worker
bin/dev
```

Open <http://localhost:3000>. `Procfile.dev` starts three processes: `web` (Rails), `css` (Tailwind watch) and `worker` (`bin/jobs`). **Searches stay in the loading state if the worker isn't running.**

Database connection defaults are `localhost:5434`, `postgres/postgres`. Override them with `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME` and `DATABASE_PASSWORD`.

> Confirmation emails need a delivery method in development (for example, letter_opener or log inspection). Without one, confirm users from the console: `User.last.confirm`.

### Useful scripts

```bash
bin/rails runner script/pipeline_console_test.rb   # exercise the domain pipeline end to end
bin/rails runner script/insights_console_test.rb   # exercise the insights builder
bin/rails airports:build                            # regenerate app/javascript/data/airports.js
```

---

## Configuration (credentials)

Rails per-environment encrypted credentials (`config/credentials/<env>.yml.enc`). Every key is optional in development: without them the app falls back to the stub provider and deterministic explanations.

```yaml
flight_provider: amadeus        # "stub" (default) | "amadeus"

amadeus:
  client_id: ...
  client_secret: ...

anthropic_api_key: ...          # enables AI route summaries and flight explanations

stripe:
  secret_key: sk_...
  webhook_secret: whsec_...
  price_pack5_usd:  price_...
  price_pack5_brl:  price_...
  price_pack15_usd: price_...
  price_pack15_brl: price_...
  price_pack30_usd: price_...
  price_pack30_brl: price_...
```

To test webhooks locally: `stripe listen --forward-to localhost:3000/stripe/webhooks`.

---

## Testing and quality

```bash
bundle exec rspec                       # full suite
bundle exec rspec spec/domain/          # domain only: pure Ruby, no DB, no mocks
bundle exec rspec path/to/file_spec.rb  # single file

bin/rubocop          # style (rubocop-rails-omakase); -a to auto-fix
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

There are 57 spec files (24 of them domain specs) covering the domain, providers (WebMock, never live HTTP), presenters, services, jobs, mailers, models, and request specs for searches, payments, webhooks, rate limiting, confirmations and history.

**Testing philosophy:**

| Layer | Stub | Real |
| --- | --- | --- |
| Domain | nothing | everything |
| Repository | domain calls | ActiveRecord |
| Controllers | repository | — |

Specs define behavior, not implementation. Don't stub domain methods in domain specs, don't test private methods, and don't delete `pending` specs (they describe planned behavior).

**CI** (GitHub Actions, `.github/workflows/ci.yml`) runs Brakeman, bundler-audit, importmap audit and RuboCop on pushes to `main` and on PRs. Dependabot is enabled.

---

## Project layout

```
app/
├── domain/search/              # business logic (pure Ruby)
│   ├── search_run.rb           # aggregate root: initialized → sampling → completed | failed
│   ├── search_execution.rb     # 8-phase pipeline orchestrator
│   ├── search_results.rb       # read-side value object (ranked_flights, insights, snapshot)
│   ├── models/                 # FlightSample, SearchIntent, AnalysisSnapshot (immutable)
│   ├── sampling/               # DateGrid, CandidateSelector, Sampler, Runner
│   ├── analysis/               # SnapshotBuilder
│   ├── scoring/                # PriceScore, TimeComfortScore, TripFit, FinalScore, Scorer
│   ├── explanation/            # Builder, FlightExplanation
│   ├── ranking/                # Ranker, RankedFlight
│   ├── insights/               # Builder, SearchInsights, DateRange/WaitOrBook/PriceRarity insights
│   ├── factories/              # AR → domain
│   ├── mappers/                # domain → AR
│   └── repositories/           # SearchRunRepository (execute, load_results)
├── providers/flights/          # Base, Stub, Registry, Amadeus::{Client,Normalizer,Provider}
├── controllers/                # pages, searches, search_history, profile, payments, stripe_webhooks, users/*
├── jobs/search_run_job.rb      # thin async wrapper, credit decrement, Turbo broadcast
├── presenters/                 # SearchResults, RankedFlight, Insights, Profile, SearchHistory, URL builder
├── services/                   # RouteSummaryCopyService, ExplanationCopyService (Claude)
├── support/                    # LocaleResolver, CurrencyResolver, PriceFormatter, AiLocale, StripeConfig
├── models/                     # User, SearchIntent, SearchRun, FlightSample, AnalysisSnapshot, CreditPurchase
├── views/                      # ERB + Tailwind; searches/_results, _low_confidence, _failed, _loading…
└── javascript/controllers/     # Stimulus: airport_autocomplete, theme_toggle, credits_dropdown
docs/                           # product, architecture, domain specs, plans (see below)
spec/                           # RSpec, mirrors app/
```

### Data model

```
User ─┬─< SearchIntent ─< SearchRun ─┬─< FlightSample
      │                              └── AnalysisSnapshot (1:1)
      └─< CreditPurchase
```

Money is stored as integer cents. Enums (`state`, `confidence_level`, `volatility`, `luggage_requirement`) are integers. Naming is fixed: `state` (not `status`), `finished_at` (not `completed_at`).

---

## Documentation map

| Document | Purpose |
| --- | --- |
| [`docs/PRODUCT_GUIDE.md`](docs/PRODUCT_GUIDE.md) | **Single source of truth** for product behavior, scope and non-goals |
| [`docs/PRD.md`](docs/PRD.md) | Smart Search execution vertical slice |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Modular monolith rules, domain vs. persistence |
| [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md) | Full directory walkthrough |
| [`docs/domain/`](docs/domain/) | Authoritative per-module specs: sampling, analysis, scoring, explanation, insights, search run, repository |
| [`docs/providers.md`](docs/providers.md) | Provider contract, Amadeus integration, adding providers |
| [`docs/design-system.md`](docs/design-system.md) | Brand, tokens, typography, color signals, accessibility |
| [`docs/curated_explanations.md`](docs/curated_explanations.md), [`docs/explanation_copy.md`](docs/explanation_copy.md) | AI copy strategy |
| [`docs/MVP_ROADMAP.md`](docs/MVP_ROADMAP.md) | MVP execution checklist |
| [`docs/PROJECT_REVIEW_2026_03_18.md`](docs/PROJECT_REVIEW_2026_03_18.md) | Product and codebase review, go-to-market, progress log |
| [`docs/temporal_price_trends.md`](docs/temporal_price_trends.md) | Next: cross-run historical signals |
| [`docs/future/affiliate-deep-links.md`](docs/future/affiliate-deep-links.md) | Future: affiliate revenue and direct booking |
| `docs/superpowers/{specs,plans}/` | Design specs and implementation plans per feature |
| `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/` | Rules for AI coding agents (kept in sync) |

---

## Roadmap and status

### ✅ Shipped (MVP core)

- 8-phase domain pipeline (sampling → insights) with ranking and four insight artifacts
- Persistence aligned with domain vocabulary, plus a recompute-on-read results layer
- Single `SearchRunJob` on Solid Queue, live results via Turbo Streams + Solid Cable
- Provider abstraction, stub provider, and Amadeus integration (verified against the test API)
- Results UI with the recommendation hero, low-confidence and failure states, and curated flight cards
- AI route summaries and per-flight explanations (Claude Haiku), localized
- Devise auth with email confirmation and welcome email
- Credits model, 1 free search, Stripe Checkout packs (USD/BRL), idempotent webhook fulfillment
- Landing page, search history, profile, nav credit balance
- Rack::Attack rate limiting
- i18n (EN, PT-BR) and design system alignment (accessibility, dark mode)

### 🚧 Remaining before launch

- [ ] Production Amadeus credentials (or the FlightAPI.io provider, which is planned)
- [ ] Error monitoring (Sentry)
- [ ] Production deploy: Kamal config is scaffolded (`config/deploy.yml`), but server IP and registry are placeholders
- [ ] Production mailer delivery settings

### 🔭 Next and later

- **FlightAPI.io provider:** drop-in `Flights::Base` implementation ([plan](docs/superpowers/plans/2026-04-10-flightapi-provider.md))
- **Temporal price trends:** price frequency, trend direction and lead-time buckets from past runs on the same route ([spec](docs/temporal_price_trends.md))
- **Skyscanner affiliate tag:** one-line change in `FlightSearchUrlBuilder`
- "Your search is ready" email, analytics, SEO route pages
- Later: price-drop alerts, subscriptions, B2B API, direct booking deep links

---

## Known gaps

These were found while reading the code against `docs/PRODUCT_GUIDE.md` and the domain specs. They're worth confirming before launch:

- **Luggage requirement is never applied in scoring.** The AR enum values are `none` / `carry_on` / `checked`, but `Scoring::TripFit` matches `:required` / `:optional`, so every flight gets full luggage fit.
- **`max_stops` is not enforced.** It's carried into `Models::SearchIntent` but no domain step filters on it.
- **Return dates can fall past `latest_return`.** `SearchRunFactory` passes `latest_return` as the latest *departure* date, so departure + stay can exceed the user's window.
- **Data freshness is not a confidence factor.** The Product Guide lists it, but `SnapshotBuilder` uses only sample count and volatility. Staleness is shown only as a 7-day UI label, and `search_runs.data_fresh_until` is unused.
- **Lifecycle vocabulary differs between docs and code.** The PRD lists `pending → sampling → analyzing`, while the code uses `initialized → sampling → completed | failed` plus the execution phases.

---

## Contributing rules

These rules come from `CLAUDE.md` / `.cursor/rules/` and apply to people and AI agents alike:

- Read `docs/PRODUCT_GUIDE.md` and the relevant `docs/domain/*` spec **before** touching `app/domain/`. Don't invent behavior. Ask when unsure.
- Use guard clauses, keep methods to 10 lines or fewer, use named constants instead of magic numbers, and write comments that explain *why*.
- Name things for business intent. Domain code doesn't use `Service` or `Manager` suffixes.
- Don't abstract prematurely. Duplication is fine until the shared concept is clear.
- Refactors must not change behavior, and specs stay green.
- Development happens directly on `main`. The maintainer handles all git operations.
