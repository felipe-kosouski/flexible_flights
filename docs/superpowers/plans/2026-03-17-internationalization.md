# Internationalization (i18n) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add EN/PT-BR locale support with currency-aware pricing (USD/BRL), translated UI copy, and AI-generated copy in the user's language.

**Architecture:** Locale is detected from the browser `Accept-Language` header on every request, persisted in session, and overridable via a user profile setting. Currency is derived from locale at search creation time, stored on `SearchIntent`, and flows through the entire domain pipeline to Amadeus and back. Four plain Ruby support objects (`LocaleResolver`, `CurrencyResolver`, `PriceFormatter`, `AiLocale`) contain all the logic — controllers and services stay thin.

**Tech Stack:** Rails I18n (built-in), Rails credentials (existing), Anthropic SDK (existing), RSpec with shoulda-matchers and factory_bot (existing).

---

## File Map

**New files:**
- `app/support/locale_resolver.rb`
- `app/support/currency_resolver.rb`
- `app/support/price_formatter.rb`
- `app/support/ai_locale.rb`
- `config/locales/en.yml`
- `config/locales/pt-BR.yml`
- `spec/support/locale_resolver_spec.rb`
- `spec/support/currency_resolver_spec.rb`
- `spec/support/price_formatter_spec.rb`
- `spec/support/ai_locale_spec.rb`

**Modified files:**
- `db/migrate/` — two new migrations
- `app/models/user.rb` — `preferred_locale` validation
- `app/models/search_intent.rb` — `currency` validation
- `app/controllers/application_controller.rb` — `set_locale` before_action
- `app/controllers/searches_controller.rb` — set `currency` on intent
- `app/domain/search/models/search_intent.rb` — `currency` attribute
- `app/domain/search/models/flight_sample.rb` — `currency` attribute
- `app/domain/search/search_run.rb` — accept/carry `currency_code:`
- `app/domain/search/factories/search_run_factory.rb` — read currency from AR record
- `app/domain/search/sampling/runner.rb` — add `currency_code:` param
- `app/domain/search/sampling/sampler.rb` — add `currency_code:` param
- `app/domain/search/mappers/flight_sample_mapper.rb` — map `currency`
- `app/providers/flights/base.rb` — optional `currency_code:` in interface
- `app/providers/flights/amadeus/provider.rb` — pass `currencyCode:` to Amadeus
- `app/providers/flights/stub.rb` — accept/ignore `currency_code:`
- `app/presenters/ranked_flight_presenter.rb` — `PriceFormatter` + `I18n.t`
- `app/presenters/insights_presenter.rb` — `PriceFormatter` + `I18n.t`
- `app/presenters/search_results_presenter.rb` — `I18n.t` + locale threaded to services
- `app/services/explanation_copy_service.rb` — `locale:` param, `AiLocale`, `PriceFormatter`
- `app/services/route_summary_copy_service.rb` — `locale:` param, `AiLocale`, `PriceFormatter`
- All views under `app/views/searches/`, `app/views/search_history/`, `app/views/profile/`
- `spec/models/user_spec.rb`, `spec/models/search_intent_spec.rb`
- `spec/domain/search/` — sampler, runner, search_run, factory, mapper
- `spec/providers/flights/amadeus/provider_spec.rb`
- `spec/services/` — both service specs
- `spec/presenters/ranked_flight_presenter_spec.rb`

**Out of scope:** Application layout nav strings (`"History"`, `"Profile"`, `"Sign out"`) are not translated in this pass.

---

## Task 1: Support Objects

Four small, pure Ruby classes with no Rails or ActiveRecord dependencies. Build and test all four before touching anything else.

**Files:**
- Create: `app/support/locale_resolver.rb`
- Create: `app/support/currency_resolver.rb`
- Create: `app/support/price_formatter.rb`
- Create: `app/support/ai_locale.rb`
- Create: `spec/support/locale_resolver_spec.rb`
- Create: `spec/support/currency_resolver_spec.rb`
- Create: `spec/support/price_formatter_spec.rb`
- Create: `spec/support/ai_locale_spec.rb`

- [ ] **Step 1: Write `LocaleResolver` spec**

```ruby
# spec/support/locale_resolver_spec.rb
require "rails_helper"

RSpec.describe LocaleResolver do
  let(:user_with_locale) { instance_double("User", preferred_locale: "pt-BR") }
  let(:user_without_locale) { instance_double("User", preferred_locale: nil) }

  describe ".resolve" do
    it "returns user preferred_locale when set and supported" do
      expect(described_class.resolve(user: user_with_locale)).to eq("pt-BR")
    end

    it "ignores unsupported user preferred_locale and falls back to session" do
      user = instance_double("User", preferred_locale: "fr")
      expect(described_class.resolve(user: user, session_locale: "en")).to eq("en")
    end

    it "falls back to session_locale when user has none" do
      expect(described_class.resolve(user: user_without_locale, session_locale: "pt-BR")).to eq("pt-BR")
    end

    it "falls back to Accept-Language header when no user or session" do
      expect(described_class.resolve(accept_language: "pt-BR,en;q=0.9")).to eq("pt-BR")
    end

    it "parses Accept-Language with quality values and picks first supported locale" do
      expect(described_class.resolve(accept_language: "en-US,en;q=0.9,pt-BR;q=0.8")).to eq("en")
    end

    it "returns default 'en' when nothing matches" do
      expect(described_class.resolve(accept_language: "fr,de")).to eq("en")
    end

    it "returns default 'en' when all inputs are nil" do
      expect(described_class.resolve).to eq("en")
    end

    it "rejects unsupported session_locale and falls back to default" do
      expect(described_class.resolve(session_locale: "zh")).to eq("en")
    end
  end
end
```

- [ ] **Step 2: Run spec — expect failure**

```bash
bundle exec rspec spec/support/locale_resolver_spec.rb
```
Expected: `LoadError` or `NameError` (class doesn't exist yet).

- [ ] **Step 3: Write `LocaleResolver`**

```ruby
# app/support/locale_resolver.rb
class LocaleResolver
  SUPPORTED = %w[en pt-BR].freeze
  DEFAULT = "en".freeze

  def self.resolve(user: nil, session_locale: nil, accept_language: nil)
    from_user(user) ||
      from_session(session_locale) ||
      from_header(accept_language) ||
      DEFAULT
  end

  private_class_method def self.from_user(user)
    return nil unless user&.preferred_locale
    supported?(user.preferred_locale) ? user.preferred_locale : nil
  end

  private_class_method def self.from_session(session_locale)
    supported?(session_locale) ? session_locale.to_s : nil
  end

  private_class_method def self.from_header(header)
    return nil unless header
    header.split(",").map { |l| l.split(";").first.strip }.find { |l| supported?(l) }
  end

  private_class_method def self.supported?(locale)
    SUPPORTED.include?(locale.to_s)
  end
end
```

- [ ] **Step 4: Run spec — expect pass**

```bash
bundle exec rspec spec/support/locale_resolver_spec.rb
```

- [ ] **Step 5: Write `CurrencyResolver` spec**

```ruby
# spec/support/currency_resolver_spec.rb
require "rails_helper"

RSpec.describe CurrencyResolver do
  describe ".for_locale" do
    it "returns USD for en" do
      expect(described_class.for_locale("en")).to eq("USD")
    end

    it "returns BRL for pt-BR" do
      expect(described_class.for_locale("pt-BR")).to eq("BRL")
    end

    it "returns USD for unknown locale" do
      expect(described_class.for_locale("fr")).to eq("USD")
    end

    it "accepts symbols" do
      expect(described_class.for_locale(:"pt-BR")).to eq("BRL")
    end
  end
end
```

- [ ] **Step 6: Write `CurrencyResolver`**

```ruby
# app/support/currency_resolver.rb
class CurrencyResolver
  LOCALE_CURRENCY = {
    "en"    => "USD",
    "pt-BR" => "BRL"
  }.freeze
  DEFAULT = "USD".freeze

  def self.for_locale(locale)
    LOCALE_CURRENCY.fetch(locale.to_s, DEFAULT)
  end
end
```

- [ ] **Step 7: Run CurrencyResolver spec — expect pass**

```bash
bundle exec rspec spec/support/currency_resolver_spec.rb
```

- [ ] **Step 8: Write `PriceFormatter` spec**

```ruby
# spec/support/price_formatter_spec.rb
require "rails_helper"

RSpec.describe PriceFormatter do
  describe ".call" do
    it "formats USD with dollar sign" do
      expect(described_class.call(53_600, "USD")).to eq("$536")
    end

    it "formats BRL with R$ symbol" do
      expect(described_class.call(234_000, "BRL")).to eq("R$2340")
    end

    it "formats EUR with euro sign" do
      expect(described_class.call(45_000, "EUR")).to eq("€450")
    end

    it "falls back to ISO code for unknown currency" do
      expect(described_class.call(10_000, "JPY")).to eq("JPY100")
    end

    it "returns N/A when cents is nil" do
      expect(described_class.call(nil, "USD")).to eq("N/A")
    end

    it "rounds fractional cents" do
      expect(described_class.call(53_650, "USD")).to eq("$537")
    end
  end
end
```

- [ ] **Step 9: Write `PriceFormatter`**

```ruby
# app/support/price_formatter.rb
class PriceFormatter
  SYMBOLS = { "USD" => "$", "BRL" => "R$", "EUR" => "€" }.freeze

  def self.call(cents, currency)
    return "N/A" unless cents
    symbol = SYMBOLS.fetch(currency.to_s, currency.to_s)
    "#{symbol}#{(cents / 100.0).round}"
  end
end
```

- [ ] **Step 10: Run PriceFormatter spec — expect pass**

```bash
bundle exec rspec spec/support/price_formatter_spec.rb
```

- [ ] **Step 11: Write `AiLocale` spec**

```ruby
# spec/support/ai_locale_spec.rb
require "rails_helper"

RSpec.describe AiLocale do
  describe ".instruction_for" do
    it "returns a Portuguese instruction for pt-BR" do
      expect(described_class.instruction_for("pt-BR")).to eq("Respond in Brazilian Portuguese (PT-BR).")
    end

    it "returns nil for en (model already defaults to English)" do
      expect(described_class.instruction_for("en")).to be_nil
    end

    it "returns nil for unknown locale" do
      expect(described_class.instruction_for("fr")).to be_nil
    end

    it "accepts symbols" do
      expect(described_class.instruction_for(:"pt-BR")).to eq("Respond in Brazilian Portuguese (PT-BR).")
    end
  end
end
```

- [ ] **Step 12: Write `AiLocale`**

```ruby
# app/support/ai_locale.rb
module AiLocale
  LANGUAGE_INSTRUCTIONS = {
    "pt-BR" => "Respond in Brazilian Portuguese (PT-BR)."
  }.freeze

  # Returns nil for English — the model defaults to English, no instruction needed.
  # Callers must guard before appending to prompts:
  #   instruction = AiLocale.instruction_for(locale)
  #   system_prompt += "\n#{instruction}" if instruction
  def self.instruction_for(locale)
    LANGUAGE_INSTRUCTIONS[locale.to_s]
  end
end
```

- [ ] **Step 13: Run all four support specs — expect all pass**

```bash
bundle exec rspec spec/support/
```

- [ ] **Step 14: Commit**

```bash
git add app/support/ spec/support/
git commit -m "feat: add LocaleResolver, CurrencyResolver, PriceFormatter, AiLocale support objects"
```

---

## Task 2: Database Migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_add_currency_to_search_intents.rb`
- Create: `db/migrate/TIMESTAMP_add_preferred_locale_to_users.rb`

- [ ] **Step 1: Generate migrations**

```bash
bin/rails generate migration AddCurrencyToSearchIntents currency:string
bin/rails generate migration AddPreferredLocaleToUsers preferred_locale:string
```

- [ ] **Step 2: Edit the currency migration to add null constraint and default**

Open the generated file and ensure it reads:

```ruby
def change
  add_column :search_intents, :currency, :string, null: false, default: "USD"
end
```

- [ ] **Step 3: Run migrations**

```bash
bin/rails db:migrate
```

- [ ] **Step 4: Verify schema**

Check `db/schema.rb`. Confirm:
- `search_intents` has `t.string "currency", null: false, default: "USD"`
- `users` has `t.string "preferred_locale"`

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add currency to search_intents and preferred_locale to users"
```

---

## Task 3: User `preferred_locale`

**Files:**
- Modify: `app/models/user.rb`
- Modify: `spec/models/user_spec.rb`

- [ ] **Step 1: Add examples to `spec/models/user_spec.rb`**

Add inside the `RSpec.describe User` block:

```ruby
describe "preferred_locale" do
  it "is valid when nil (browser detection used)" do
    user = build(:user, preferred_locale: nil)
    expect(user).to be_valid
  end

  it "is valid for a supported locale" do
    user = build(:user, preferred_locale: "pt-BR")
    expect(user).to be_valid
  end

  it "is invalid for an unsupported locale" do
    user = build(:user, preferred_locale: "fr")
    expect(user).not_to be_valid
    expect(user.errors[:preferred_locale]).to be_present
  end
end
```

- [ ] **Step 2: Run — expect failure**

```bash
bundle exec rspec spec/models/user_spec.rb
```

- [ ] **Step 3: Add validation to `app/models/user.rb`**

```ruby
SUPPORTED_LOCALES = %w[en pt-BR].freeze

validates :preferred_locale,
  inclusion: { in: SUPPORTED_LOCALES },
  allow_nil: true
```

- [ ] **Step 4: Run — expect pass**

```bash
bundle exec rspec spec/models/user_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add app/models/user.rb spec/models/user_spec.rb
git commit -m "feat: add preferred_locale validation to User"
```

---

## Task 4: ApplicationController Locale Wiring

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `config/application.rb`

- [ ] **Step 1: Set available locales in `config/application.rb`**

Add inside the `Application` class:

```ruby
config.i18n.available_locales = %w[en pt-BR]
config.i18n.default_locale = :en
```

- [ ] **Step 2: Add `set_locale` to `ApplicationController`**

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_locale

  private

  def set_locale
    locale = LocaleResolver.resolve(
      user: current_user,
      session_locale: session[:locale],
      accept_language: request.env["HTTP_ACCEPT_LANGUAGE"]
    )
    session[:locale] = locale
    I18n.locale = locale
  end
end
```

- [ ] **Step 3: Verify existing request specs still pass**

```bash
bundle exec rspec spec/requests/
```
Expected: all green (locale defaults to `"en"`, no change in behavior for existing tests).

- [ ] **Step 4: Commit**

```bash
git add app/controllers/application_controller.rb config/application.rb
git commit -m "feat: wire locale detection in ApplicationController via LocaleResolver"
```

---

## Task 5: SearchIntent Currency

Currency is set at search creation time from the user's locale. It flows through the factory into the domain pipeline. Three layers to update: AR model, domain model, factory, and controller.

**Files:**
- Modify: `app/models/search_intent.rb`
- Modify: `app/domain/search/models/search_intent.rb`
- Modify: `app/domain/search/factories/search_run_factory.rb`
- Modify: `app/controllers/searches_controller.rb`
- Modify: `spec/models/search_intent_spec.rb`
- Modify: `spec/domain/search/search_run_factory_spec.rb`

- [ ] **Step 1: Add currency validation to `spec/models/search_intent_spec.rb`**

Inside the `describe "validations"` block, add:

```ruby
it { is_expected.to validate_presence_of(:currency) }
```

- [ ] **Step 2: Run — expect failure**

```bash
bundle exec rspec spec/models/search_intent_spec.rb
```

- [ ] **Step 3: Add validation to `app/models/search_intent.rb`**

```ruby
validates :currency, presence: true
```

- [ ] **Step 4: Run — expect pass**

```bash
bundle exec rspec spec/models/search_intent_spec.rb
```

- [ ] **Step 5: Add `currency` spec for domain `Models::SearchIntent`**

Find the domain spec file (likely `spec/domain/search/models/search_intent_spec.rb` — create it if absent). Add:

```ruby
require "rails_helper"

RSpec.describe Search::Models::SearchIntent do
  describe "#currency" do
    it "defaults to USD" do
      intent = described_class.new(min_stay_days: 5, max_stay_days: 10, luggage_requirement: :none)
      expect(intent.currency).to eq("USD")
    end

    it "stores the provided currency" do
      intent = described_class.new(min_stay_days: 5, max_stay_days: 10, luggage_requirement: :none, currency: "BRL")
      expect(intent.currency).to eq("BRL")
    end
  end
end
```

- [ ] **Step 6: Run — expect failure**

```bash
bundle exec rspec spec/domain/search/models/
```

- [ ] **Step 7: Add `currency` attribute to `app/domain/search/models/search_intent.rb`**

```ruby
attr_reader :min_stay_days, :max_stay_days, :luggage_requirement, :max_stops, :currency

def initialize(
  min_stay_days:,
  max_stay_days:,
  luggage_requirement:,
  max_stops: nil,
  currency: "USD"
)
  @min_stay_days = min_stay_days
  @max_stay_days = max_stay_days
  @luggage_requirement = luggage_requirement
  @max_stops = max_stops
  @currency = currency
end
```

- [ ] **Step 8: Run — expect pass**

```bash
bundle exec rspec spec/domain/search/models/
```

- [ ] **Step 9: Update `SearchRunFactory.intent_from_record` to read currency**

In `app/domain/search/factories/search_run_factory.rb`, update `intent_from_record`:

```ruby
def self.intent_from_record(search_run_record)
  intent = search_run_record.search_intent

  Models::SearchIntent.new(
    min_stay_days: intent.min_stay_days,
    max_stay_days: intent.max_stay_days,
    luggage_requirement: intent.luggage_requirement&.to_sym,
    max_stops: intent.max_stops,
    currency: intent.currency
  )
end
```

- [ ] **Step 10: Set currency in `SearchesController#create`**

Find `@search_intent = current_user.search_intents.build(search_intent_params)` and add immediately after:

```ruby
@search_intent.currency = CurrencyResolver.for_locale(I18n.locale)
```

- [ ] **Step 11: Run full suite — expect green**

```bash
bundle exec rspec
```

- [ ] **Step 12: Commit**

```bash
git add app/models/search_intent.rb \
        app/domain/search/models/search_intent.rb \
        app/domain/search/factories/search_run_factory.rb \
        app/controllers/searches_controller.rb \
        spec/models/search_intent_spec.rb \
        spec/domain/search/models/search_intent_spec.rb \
        spec/domain/search/search_run_factory_spec.rb
git commit -m "feat: add currency to SearchIntent and set from user locale at search creation"
```

---

## Task 6: Currency Through the Domain Pipeline

`currency_code` flows: `SearchRun` → `Sampling::Runner` → `Sampling::Sampler` → provider. `FlightSample` domain model gains a `currency` attribute surfaced from the raw hash via the mapper. Note: `SearchRunRepository.execute` signature does **not** change — currency is sourced from `search_intent.currency` inside the factory.

**Files:**
- Modify: `app/domain/search/search_run.rb`
- Modify: `app/domain/search/factories/search_run_factory.rb`
- Modify: `app/domain/search/sampling/runner.rb`
- Modify: `app/domain/search/sampling/sampler.rb`
- Modify: `app/domain/search/models/flight_sample.rb`
- Modify: `app/domain/search/mappers/flight_sample_mapper.rb`
- Modify: `app/providers/flights/base.rb`
- Modify: `app/providers/flights/amadeus/provider.rb`
- Modify: `app/providers/flights/stub.rb`
- Modify: `spec/domain/search/search_run_spec.rb`
- Modify: `spec/domain/search/sampling/runner_spec.rb`
- Modify: `spec/domain/search/sampling/sampler_spec.rb`
- Modify: `spec/domain/search/models/flight_sample_spec.rb` (create if absent)
- Modify: `spec/domain/search/mappers/flight_sample_mapper_spec.rb`
- Modify: `spec/providers/flights/amadeus/provider_spec.rb`

- [ ] **Step 1: Add `currency_code` forwarding spec to `spec/domain/search/search_run_spec.rb`**

The existing spec already stubs `Sampling::Runner` with a `class_double` under `stub_const`. Add a new example inside the existing describe block (the `before` block with `stub_const` applies to all examples):

```ruby
it "forwards currency_code to Sampling::Runner" do
  allow(runner).to receive(:call).and_return([])

  search_run_brl = described_class.new(
    origin: origin, destination: destination,
    earliest_departure_date: earliest_departure_date,
    latest_departure_date: latest_departure_date,
    min_stay_days: min_stay_days, max_stay_days: max_stay_days,
    max_candidates: max_candidates, passengers: passengers,
    cabin_class: cabin_class, provider: provider,
    currency_code: "BRL"
  )
  search_run_brl.execute

  expect(runner).to have_received(:call).with(hash_including(currency_code: "BRL"))
end

it "defaults currency_code to USD" do
  allow(runner).to receive(:call).and_return([])
  search_run.execute
  expect(runner).to have_received(:call).with(hash_including(currency_code: "USD"))
end
```

Note: `runner` is a `class_double` already replacing `Sampling::Runner` via `stub_const` in the `before` block — `allow(runner).to receive(:call)` stubs the class-level `.call` method correctly.

- [ ] **Step 2: Run — expect failure**

```bash
bundle exec rspec spec/domain/search/search_run_spec.rb
```

- [ ] **Step 3: Update `SearchRun` to accept and forward `currency_code`**

In `app/domain/search/search_run.rb`:

Add `currency_code: "USD"` to `initialize` keyword args, assign `@currency_code = currency_code`.

In `execute`, add `currency_code: @currency_code` to the `Sampling::Runner.call(...)` hash.

- [ ] **Step 4: Update `SearchRunFactory.from_record` to pass `currency_code`**

In `app/domain/search/factories/search_run_factory.rb`, update `from_record`:

```ruby
SearchRun.new(
  origin: intent.origin_airport,
  destination: intent.destination_airport,
  earliest_departure_date: intent.earliest_departure,
  latest_departure_date: intent.latest_return,
  min_stay_days: intent.min_stay_days,
  max_stay_days: intent.max_stay_days,
  max_candidates: max_candidates,
  passengers: passengers,
  cabin_class: cabin_class,
  currency_code: intent.currency,
  provider: provider
)
```

- [ ] **Step 5: Run SearchRun + factory specs — expect pass**

```bash
bundle exec rspec spec/domain/search/search_run_spec.rb spec/domain/search/search_run_factory_spec.rb
```

- [ ] **Step 6: Add `currency_code` spec to `spec/domain/search/sampling/runner_spec.rb`**

```ruby
it "passes currency_code to Sampler" do
  sampler_double = instance_double(Search::Sampling::Sampler, call: [])
  allow(Search::Sampling::Sampler).to receive(:new).and_return(sampler_double)

  described_class.call(
    origin: "GRU", destination: "LHR",
    earliest_departure_date: Date.today + 30,
    latest_departure_date: Date.today + 60,
    min_stay_days: 5, max_stay_days: 10,
    max_candidates: 5, provider: double("provider", search: []),
    currency_code: "BRL"
  )

  expect(Search::Sampling::Sampler).to have_received(:new).with(hash_including(currency_code: "BRL"))
end
```

- [ ] **Step 7: Update `Sampling::Runner` to accept and forward `currency_code`**

In `app/domain/search/sampling/runner.rb`:

Add `currency_code: "USD"` to `initialize` params, `@currency_code = currency_code`.

In `sample_flights`, add `currency_code: @currency_code` to `Sampler.new(...)`.

- [ ] **Step 8: Add `currency_code` spec to `spec/domain/search/sampling/sampler_spec.rb`**

Update the existing "calls provider with correct parameters" example to include `currency_code: "BRL"` in the sampler constructor and verify the provider receives it:

```ruby
sampler = described_class.new(
  origin: "NYC", destination: "LON",
  date_pairs: [[departure_date, return_date]],
  passengers: 2, cabin_class: :business,
  currency_code: "BRL",
  provider: provider
)
sampler.call
expect(provider).to have_received(:search).with(
  origin: "NYC", destination: "LON",
  departure_date: departure_date, return_date: return_date,
  passengers: 2, cabin_class: :business,
  currency_code: "BRL"
)
```

Also add:
```ruby
it "defaults currency_code to USD" do
  provider = double("Provider", search: [valid_sample])
  sampler = described_class.new(
    origin: "NYC", destination: "LON",
    date_pairs: [[departure_date, return_date]],
    provider: provider
  )
  sampler.call
  expect(provider).to have_received(:search).with(hash_including(currency_code: "USD"))
end
```

- [ ] **Step 9: Update `Sampling::Sampler` to pass `currency_code` to provider**

In `app/domain/search/sampling/sampler.rb`:

Add `currency_code: "USD"` to `initialize` params, `@currency_code = currency_code`.

In `fetch_results`, add `currency_code: @currency_code` to `@provider.search(...)`.

- [ ] **Step 10: Update provider interface and implementations**

In `app/providers/flights/base.rb`, add `currency_code:` to the method signature docstring comment.

In `app/providers/flights/amadeus/provider.rb`:
- Add `currency_code: "USD"` to `search` params
- Add `currencyCode: currency_code` to the `@client.flight_offers(...)` params hash

In `app/providers/flights/stub.rb`:
- Add `currency_code: "USD"` to `search` params and ignore it
- Note: stub continues returning `currency: "EUR"` — price display in development will show `€` regardless of locale; this is expected

- [ ] **Step 11: Add `currency` attribute spec for domain `Models::FlightSample`**

Find or create `spec/domain/search/models/flight_sample_spec.rb`. Add:

```ruby
describe "#currency" do
  it "stores and returns the currency" do
    sample = described_class.new(
      departure_datetime: Time.now,
      return_datetime: Time.now + 7.days,
      luggage_included: false,
      currency: "BRL"
    )
    expect(sample.currency).to eq("BRL")
  end

  it "defaults to USD" do
    sample = described_class.new(
      departure_datetime: Time.now,
      return_datetime: Time.now + 7.days,
      luggage_included: false
    )
    expect(sample.currency).to eq("USD")
  end
end
```

- [ ] **Step 12: Run — expect failure**

```bash
bundle exec rspec spec/domain/search/models/flight_sample_spec.rb
```

- [ ] **Step 13: Add `currency` attribute to `app/domain/search/models/flight_sample.rb`**

Add `currency: "USD"` to `initialize` params and assign `@currency = currency`. Add `attr_reader :currency` (or an explicit `def currency` method consistent with the existing pattern in the file).

- [ ] **Step 14: Update `FlightSampleMapper` to map `currency`**

In `app/domain/search/mappers/flight_sample_mapper.rb`, add `currency: raw[:currency]` to the `Models::FlightSample.new(...)` call.

In `spec/domain/search/mappers/flight_sample_mapper_spec.rb`, ensure the raw sample hash includes `currency: "BRL"` and add:

```ruby
it "maps currency from the raw sample" do
  expect(mapped.currency).to eq("BRL")
end
```

- [ ] **Step 15: Add `currencyCode` spec to Amadeus provider**

In `spec/providers/flights/amadeus/provider_spec.rb`:

```ruby
it "passes currencyCode to the Amadeus client" do
  allow(client).to receive(:flight_offers).and_return({ "data" => [] })
  provider.search(
    origin: "GRU", destination: "LHR",
    departure_date: Date.today, return_date: Date.today + 7,
    passengers: 1, cabin_class: :economy,
    currency_code: "BRL"
  )
  expect(client).to have_received(:flight_offers).with(hash_including(currencyCode: "BRL"))
end
```

- [ ] **Step 16: Run full domain + provider suite — expect pass**

```bash
bundle exec rspec spec/domain/ spec/providers/
```

- [ ] **Step 17: Commit**

```bash
git add app/domain/ app/providers/ spec/domain/ spec/providers/
git commit -m "feat: thread currency_code through domain pipeline to Amadeus; add currency to FlightSample"
```

---

## Task 7: Price Display

Replace every hardcoded `"$#{cents}"` pattern with `PriceFormatter.call`. There are five occurrences across three files: `RankedFlightPresenter` (1), `InsightsPresenter` (2), `ExplanationCopyService` (2).

**Files:**
- Modify: `app/presenters/ranked_flight_presenter.rb`
- Modify: `app/presenters/insights_presenter.rb`
- Modify: `app/services/explanation_copy_service.rb`
- Modify: `spec/presenters/ranked_flight_presenter_spec.rb`
- Modify: `spec/presenters/insights_presenter_spec.rb`

- [ ] **Step 1: Update `RankedFlightPresenter#format_price`**

Replace the private `format_price` method and the `price` method:

```ruby
def price
  PriceFormatter.call(flight.price_cents, flight.currency)
end

# Keep format_price for internal use (score breakdowns etc.), but make it currency-aware:
def format_price(cents, currency = flight.currency)
  PriceFormatter.call(cents, currency)
end
```

- [ ] **Step 2: Update `InsightsPresenter::WaitOrBookPresenter#top_price`**

Replace:
```ruby
"$#{(cents / 100.0).round}"
```
With:
```ruby
PriceFormatter.call(cents, @insight.currency || "USD")
```

Note: the `WaitOrBookInsight` domain object may not carry `currency` yet — if `@insight.currency` raises `NoMethodError`, use `"USD"` as the fallback for now. This field will be properly populated when the insight is built from real search data with the currency threaded through.

- [ ] **Step 3: Update `InsightsPresenter::PriceRarityPresenter#market_price`**

Same pattern:
```ruby
PriceFormatter.call(cents, @insight.currency || "USD")
```

- [ ] **Step 4: Update `ExplanationCopyService#format_price` and `#price_delta_label`**

Replace the private `format_price` method:
```ruby
def format_price(cents)
  PriceFormatter.call(cents, currency_code)
end
```

Replace `price_delta_label` — the `$` on line 232 is inside the AI prompt data, not the UI:
```ruby
def price_delta_label
  median = baselines[:price_median_cents]
  return "N/A" unless median && median > 0 && flight.price_cents

  delta_cents = flight.price_cents - median
  pct = ((delta_cents.abs.to_f / median) * 100).round
  direction = delta_cents < 0 ? "below" : "above"
  qualifier = delta_cents < 0 ? "cheaper" : "more expensive"
  "#{PriceFormatter.call(delta_cents.abs, currency_code)} #{direction} (#{pct}% #{qualifier})"
end

private

def currency_code
  flight.currency || "USD"
end
```

- [ ] **Step 5: Run presenter and service specs**

```bash
bundle exec rspec spec/presenters/ spec/services/explanation_copy_service_spec.rb
```

- [ ] **Step 6: Commit**

```bash
git add app/presenters/ app/services/explanation_copy_service.rb spec/presenters/
git commit -m "feat: replace hardcoded dollar sign with PriceFormatter across presenters and services"
```

---

## Task 8: AI Copy Locale

Both AI services receive a `locale:` param, inject a language instruction into the system prompt, and include locale in cache keys. The call sites in `SearchResultsPresenter` are updated last.

**Files:**
- Modify: `app/services/explanation_copy_service.rb`
- Modify: `app/services/route_summary_copy_service.rb`
- Modify: `app/presenters/search_results_presenter.rb`
- Modify: `spec/services/explanation_copy_service_spec.rb`
- Modify: `spec/services/route_summary_copy_service_spec.rb`

- [ ] **Step 1: Add locale examples to `spec/services/explanation_copy_service_spec.rb`**

```ruby
describe "locale support" do
  it "includes PT-BR language instruction in system prompt" do
    client = instance_double(Anthropic::Client)
    messages_double = instance_double("Messages")
    allow(Anthropic::Client).to receive(:new).and_return(client)
    allow(client).to receive(:messages).and_return(messages_double)
    allow(messages_double).to receive(:create) do |params|
      expect(params[:system]).to include("Respond in Brazilian Portuguese (PT-BR).")
      double("Message", content: [])
    end

    described_class.call(ranked_flight: ranked_flight, intent: intent, locale: "pt-BR")
  end

  it "omits language instruction for en" do
    client = instance_double(Anthropic::Client)
    messages_double = instance_double("Messages")
    allow(Anthropic::Client).to receive(:new).and_return(client)
    allow(client).to receive(:messages).and_return(messages_double)
    allow(messages_double).to receive(:create) do |params|
      expect(params[:system]).not_to include("Respond in")
      double("Message", content: [])
    end

    described_class.call(ranked_flight: ranked_flight, intent: intent, locale: "en")
  end

  it "produces different fingerprints for en and pt-BR" do
    en_fp = described_class.fingerprint_for(ranked_flight, locale: "en")
    pt_fp = described_class.fingerprint_for(ranked_flight, locale: "pt-BR")
    expect(en_fp).not_to eq(pt_fp)
  end
end
```

- [ ] **Step 2: Run — expect failure**

```bash
bundle exec rspec spec/services/explanation_copy_service_spec.rb
```

- [ ] **Step 3: Update `ExplanationCopyService` for locale support**

Changes (in order):

1. **`self.fingerprint_for`** — add `locale:` param and include it:
   ```ruby
   def self.fingerprint_for(ranked_flight, locale: I18n.locale.to_s)
     baselines = ranked_flight.explanation.baselines
     [
       locale,
       ranked_flight.rank,
       ranked_flight.flight.price_cents,
       ranked_flight.flight.departure_datetime.to_i,
       ranked_flight.flight.return_datetime.to_i,
       baselines[:price_median_cents],
       baselines[:volatility]
     ].join("/")
   end
   ```

2. **`self.call`** — add `locale: I18n.locale.to_s` param, pass to `new`

3. **`self.batch_call`** — add `locale: I18n.locale.to_s` param, pass to `new` and to `batch_fetch_from_api`

4. **`self.batch_fetch_from_api`** — add `locale:` param and use localized system prompt:
   ```ruby
   private_class_method def self.batch_fetch_from_api(api_key, flight_sections, count, locale:)
     prompt = build_batch_prompt(flight_sections)
     instruction = AiLocale.instruction_for(locale)
     system = instruction ? "#{SYSTEM_PROMPT}\n#{instruction}" : SYSTEM_PROMPT
     client = Anthropic::Client.new(api_key: api_key)
     message = client.messages.create(
       model: MODEL,
       max_tokens: 256 * count,
       system: system,
       messages: [{ role: "user", content: prompt }]
     )
     # ... rest unchanged
   end
   ```

5. **`initialize`** — add `@locale = locale`

6. **`cache_key`** — include `@locale`

7. **`fetch_from_api`** — use `localized_system_prompt` instead of `SYSTEM_PROMPT`

8. **Private helper:**
   ```ruby
   def localized_system_prompt
     instruction = AiLocale.instruction_for(@locale)
     instruction ? "#{SYSTEM_PROMPT}\n#{instruction}" : SYSTEM_PROMPT
   end
   ```

- [ ] **Step 4: Run ExplanationCopyService spec — expect pass**

```bash
bundle exec rspec spec/services/explanation_copy_service_spec.rb
```

- [ ] **Step 5: Update `RouteSummaryCopyService` for locale support**

1. **`self.call`** — add `locale: I18n.locale.to_s` param
2. **`initialize`** — add `@locale = locale`
3. **`format_price`** — replace `@snapshot.currency` (which doesn't exist) with `@intent&.currency || "USD"`:
   ```ruby
   def format_price(cents)
     PriceFormatter.call(cents, @intent&.currency || "USD")
   end
   ```
4. **`cache_key`** — include `@locale`
5. **Private `localized_system_prompt`** — same pattern as `ExplanationCopyService`
6. **`fetch_from_api`** — use `localized_system_prompt`

- [ ] **Step 6: Run RouteSummaryCopyService spec — expect pass**

```bash
bundle exec rspec spec/services/route_summary_copy_service_spec.rb
```

- [ ] **Step 7: Update call sites in `SearchResultsPresenter`**

There are two call sites and one `fingerprint_for` call to update in `app/presenters/search_results_presenter.rb`:

**Line 16 — `fingerprint_for`:**
```ruby
fingerprint = ExplanationCopyService.fingerprint_for(rf, locale: I18n.locale.to_s)
```

**`batch_ai_copy` private method (lines 106–110) — `batch_call`:**
```ruby
def batch_ai_copy
  @batch_ai_copy ||= ExplanationCopyService.batch_call(
    ranked_flights: curated_flights,
    intent: @search_run.search_intent,
    total_flights: @results.ranked_flights.size,
    locale: I18n.locale.to_s
  )
end
```

**`route_ai_summary` private method (lines 114–119) — `call`:**
```ruby
def route_ai_summary
  @route_ai_summary ||= RouteSummaryCopyService.call(
    insights: @results.insights,
    snapshot: @results.snapshot,
    intent: @search_run.search_intent,
    locale: I18n.locale.to_s
  )
end
```

- [ ] **Step 8: Run full suite**

```bash
bundle exec rspec
```

- [ ] **Step 9: Commit**

```bash
git add app/services/ app/presenters/search_results_presenter.rb spec/services/
git commit -m "feat: add locale support to AI copy services — PT-BR responses and locale-scoped cache keys"
```

---

## Task 9: I18n Translation Files + Views + Presenter Labels

Extract all hardcoded strings to locale files. This is the highest-volume task — work file by file.

**Files:**
- Create: `config/locales/en.yml`
- Create: `config/locales/pt-BR.yml`
- Modify: all presenter files and all view partials listed below

**Note:** Application layout nav strings (`"History"`, `"Profile"`, `"Sign out"`) are out of scope for this task.

- [ ] **Step 1: Create `config/locales/en.yml`**

```yaml
en:
  flights:
    tags:
      top_rated: "Top rated"
      best_price: "Best price"
      best_comfort: "Best comfort"
    stops:
      direct: "Direct"
      one_stop: "1 stop"
      many_stops: "%{count} stops"
    score_labels:
      excellent: "Excellent"
      good: "Good"
      fair: "Fair"
      poor: "Poor"
    luggage:
      included: "Luggage included"
      carry_on_only: "Carry-on only"
    score_breakdown:
      price: "Price"
      comfort: "Comfort"
      trip_fit: "Trip fit"
      total: "Total"
    labels:
      score: "score"
      search_this_flight: "Search this flight:"
      google_flights: "Google Flights"
      skyscanner: "Skyscanner"
  searches:
    new:
      title: "Find the best time to fly"
      subtitle: "We'll scan your travel window and tell you when to go — and whether to book now or wait."
      from_label: "From"
      to_label: "To"
      submit: "Search flights"
      earliest_departure: "Earliest departure"
      latest_return: "Latest return"
      min_stay: "Min stay (days)"
      max_stay: "Max stay (days)"
      max_stops_label: "Max stops"
      luggage_label: "Luggage"
    show:
      loading_title: "Searching for flights"
      loading_subtitle: "We're analysing your travel window. This usually takes 15–30 seconds."
      search_again: "Search again"
      options_analysed: "options analysed"
      failed_title: "Search failed"
      failed_body: "Something went wrong while searching. Please try again."
      try_again: "Try again"
    history:
      title: "Search history"
      no_searches: "No searches yet."
      run_search: "Run a new search"
  insights:
    confidence:
      high: "High confidence"
      medium: "Medium confidence"
      low: "Low confidence"
    low_confidence_title: "Not enough data for reliable insights"
    low_confidence_body: "Flights are shown but no recommendations are made."
    flights_found: "Flights found"
    recommendation_label: "Recommendation"
    price_level_label: "Price level"
    best_time_label: "Best time to travel"
    best_value_label: "Best value window"
    no_detailed_insights: "Not enough data for detailed insights."
    wait_or_book:
      book_now: "Book Now"
      wait: "Wait"
      consider_booking: "Consider Booking"
      insufficient_data: "Not Enough Data"
    price_band:
      cheap: "Prices are cheap right now"
      below_median: "Prices are below average"
      above_median: "Prices are above average"
      expensive: "Prices are high"
    price_rarity:
      rare_cheap: "Rare deal"
      below_median: "Below average"
      above_median: "Above average"
      expensive: "Expensive"
    date_range:
      description_high: "Strong market signal for this window."
      description_medium: "Based on available data, this window looks favorable."
    subtext:
      insufficient_data: "Not enough data to make a reliable recommendation for this route yet."
      high_book_now: "Prices are at a good level right now — waiting risks paying more."
      high_wait: "Prices are elevated for this route. Better options are likely ahead."
      high_consider_booking: "Conditions are reasonable. Booking now is a solid choice."
      medium_book_now: "Prices suggest this may be a good time to book."
      medium_wait: "Prices suggest waiting could pay off for this route."
      medium_consider_booking: "Prices appear reasonable, though the data picture isn't fully clear."
    price_rarity_description:
      high_rare_cheap: "Prices are unusually low for this route right now."
      high_below_median: "Prices are below the typical range for this route."
      high_above_median: "Prices are above the typical range for this route."
      high_expensive: "Prices are high relative to this route's history."
      medium_rare_cheap: "Prices appear lower than usual, though data is limited."
      medium_below_median: "Prices appear to be below average."
      medium_above_median: "Prices appear to be above average."
      medium_expensive: "Prices appear high, though data is limited."
    freshness:
      pending: "Analysis pending"
      days_ago_one: "Analysed 1 day ago"
      days_ago_other: "Analysed %{count} days ago"
      stale_suffix: " · consider running again"
  profile:
    locale_label: "Language & currency"
    locale_auto: "Auto-detect from browser"
```

- [ ] **Step 2: Create `config/locales/pt-BR.yml`**

```yaml
pt-BR:
  flights:
    tags:
      top_rated: "Melhor avaliado"
      best_price: "Melhor preço"
      best_comfort: "Melhor conforto"
    stops:
      direct: "Direto"
      one_stop: "1 parada"
      many_stops: "%{count} paradas"
    score_labels:
      excellent: "Excelente"
      good: "Bom"
      fair: "Regular"
      poor: "Fraco"
    luggage:
      included: "Bagagem incluída"
      carry_on_only: "Apenas bagagem de mão"
    score_breakdown:
      price: "Preço"
      comfort: "Conforto"
      trip_fit: "Adequação"
      total: "Total"
    labels:
      score: "pontuação"
      search_this_flight: "Buscar este voo:"
      google_flights: "Google Flights"
      skyscanner: "Skyscanner"
  searches:
    new:
      title: "Encontre o melhor momento para voar"
      subtitle: "Vamos analisar sua janela de viagem e dizer quando ir — e se você deve reservar agora ou esperar."
      from_label: "De"
      to_label: "Para"
      submit: "Buscar voos"
      earliest_departure: "Saída mais cedo"
      latest_return: "Retorno mais tarde"
      min_stay: "Estadia mínima (dias)"
      max_stay: "Estadia máxima (dias)"
      max_stops_label: "Máximo de escalas"
      luggage_label: "Bagagem"
    show:
      loading_title: "Buscando voos"
      loading_subtitle: "Estamos analisando sua janela de viagem. Geralmente leva 15–30 segundos."
      search_again: "Nova busca"
      options_analysed: "opções analisadas"
      failed_title: "Busca falhou"
      failed_body: "Algo deu errado durante a busca. Por favor, tente novamente."
      try_again: "Tentar novamente"
    history:
      title: "Histórico de buscas"
      no_searches: "Nenhuma busca ainda."
      run_search: "Fazer uma nova busca"
  insights:
    confidence:
      high: "Alta confiança"
      medium: "Confiança média"
      low: "Baixa confiança"
    low_confidence_title: "Dados insuficientes para recomendações confiáveis"
    low_confidence_body: "Os voos são exibidos, mas sem recomendações."
    flights_found: "Voos encontrados"
    recommendation_label: "Recomendação"
    price_level_label: "Nível de preço"
    best_time_label: "Melhor período para viajar"
    best_value_label: "Melhor custo-benefício"
    no_detailed_insights: "Dados insuficientes para insights detalhados."
    wait_or_book:
      book_now: "Reserve agora"
      wait: "Aguarde"
      consider_booking: "Considere reservar"
      insufficient_data: "Dados insuficientes"
    price_band:
      cheap: "Preços estão baixos agora"
      below_median: "Preços abaixo da média"
      above_median: "Preços acima da média"
      expensive: "Preços estão altos"
    price_rarity:
      rare_cheap: "Oferta rara"
      below_median: "Abaixo da média"
      above_median: "Acima da média"
      expensive: "Caro"
    date_range:
      description_high: "Forte sinal de mercado para este período."
      description_medium: "Com base nos dados disponíveis, este período parece favorável."
    subtext:
      insufficient_data: "Dados insuficientes para uma recomendação confiável para esta rota."
      high_book_now: "Os preços estão num bom nível agora — esperar pode custar mais."
      high_wait: "Os preços estão elevados para esta rota. Melhores opções devem surgir."
      high_consider_booking: "As condições são razoáveis. Reservar agora é uma boa escolha."
      medium_book_now: "Os preços sugerem que pode ser um bom momento para reservar."
      medium_wait: "Os preços sugerem que esperar pode valer a pena nesta rota."
      medium_consider_booking: "Os preços parecem razoáveis, mas os dados ainda não são totalmente claros."
    price_rarity_description:
      high_rare_cheap: "Os preços estão incomumente baixos para esta rota agora."
      high_below_median: "Os preços estão abaixo da faixa típica para esta rota."
      high_above_median: "Os preços estão acima da faixa típica para esta rota."
      high_expensive: "Os preços estão altos em relação ao histórico desta rota."
      medium_rare_cheap: "Os preços parecem mais baixos que o usual, mas os dados são limitados."
      medium_below_median: "Os preços parecem estar abaixo da média."
      medium_above_median: "Os preços parecem estar acima da média."
      medium_expensive: "Os preços parecem altos, mas os dados são limitados."
    freshness:
      pending: "Análise pendente"
      days_ago_one: "Analisado há 1 dia"
      days_ago_other: "Analisado há %{count} dias"
      stale_suffix: " · considere executar novamente"
  profile:
    locale_label: "Idioma e moeda"
    locale_auto: "Detectar automaticamente"
```

- [ ] **Step 3: Update presenter label methods to use `I18n.t`**

In `app/presenters/ranked_flight_presenter.rb`, replace constant hashes with `I18n.t` calls:

```ruby
# Remove TAG_LABELS, EXPLANATION_KEY_LABELS, DIMENSION_LABELS, TRADEOFF_LABELS constants

def tag_label(tag)
  I18n.t("flights.tags.#{tag}")
end

def score_label
  case score_result.value
  when 80..100 then I18n.t("flights.score_labels.excellent")
  when 60..79  then I18n.t("flights.score_labels.good")
  when 40..59  then I18n.t("flights.score_labels.fair")
  else              I18n.t("flights.score_labels.poor")
  end
end

def stops_label
  case flight.stops
  when 0 then I18n.t("flights.stops.direct")
  when 1 then I18n.t("flights.stops.one_stop")
  else        I18n.t("flights.stops.many_stops", count: flight.stops)
  end
end

def luggage_label
  key = flight.luggage_included? ? "included" : "carry_on_only"
  I18n.t("flights.luggage.#{key}")
end
```

For `template_summary` and `template_tradeoffs` (which used the removed constants), replace with `I18n.t` calls using the same key pattern.

In `app/presenters/insights_presenter.rb`, replace all hardcoded strings with `I18n.t`:

```ruby
# WaitOrBookPresenter#directive_label
def directive_label
  key = @insight.directive == :insufficient_data ? "insufficient_data" : @insight.directive.to_s
  I18n.t("insights.wait_or_book.#{key}")
end

# WaitOrBookPresenter#price_band_label
def price_band_label
  I18n.t("insights.price_band.#{@insight.price_band}")
end

# WaitOrBookPresenter#subtext
def subtext
  return I18n.t("insights.subtext.insufficient_data") if @insight.directive == :insufficient_data
  key = "#{@insight.confidence_level}_#{@insight.directive}"
  I18n.t("insights.subtext.#{key}", default: nil)
end

# DateRangePresenter#description
def description
  I18n.t("insights.date_range.description_#{@insight.confidence_level}", default: nil)
end

# PriceRarityPresenter#label
def label
  I18n.t("insights.price_rarity.#{@insight.classification}")
end

# PriceRarityPresenter#description
def description
  key = "#{@insight.confidence_level}_#{@insight.classification}"
  I18n.t("insights.price_rarity_description.#{key}", default: nil)
end
```

In `app/presenters/search_results_presenter.rb`, replace hardcoded strings:

```ruby
def confidence_label
  I18n.t("insights.confidence.#{@results.snapshot.confidence}")
end

def freshness_label
  return I18n.t("insights.freshness.pending") unless @search_run.finished_at.present?
  days = ((Time.current - @search_run.finished_at) / 1.day).floor
  label = I18n.t("insights.freshness.days_ago", count: days)
  stale? ? label + I18n.t("insights.freshness.stale_suffix") : label
end
```

Note: `days_ago` uses Rails pluralization — define both `days_ago_one` and `days_ago_other` in locale files (already done in Step 1/2). The key `"insights.freshness.days_ago"` with `count:` will auto-resolve to `one` or `other`.

- [ ] **Step 4: Update views with `t()` calls**

Work through each file, replacing every hardcoded string with the matching `t("...")` key:

- `app/views/searches/new.html.erb` — title, subtitle, field labels, submit button
- `app/views/searches/show.html.erb` — Turbo subscription wrapper, search again link
- `app/views/searches/_loading.html.erb` — loading title, loading subtitle
- `app/views/searches/_failed.html.erb` — failed title, failed body, try again link
- `app/views/searches/_results.html.erb` — confidence labels, options analysed, insights headings
- `app/views/searches/_low_confidence.html.erb` — low confidence title, body, flights found heading
- `app/views/searches/_insights.html.erb` — recommendation label, price level label, best time label, best value label, no-insights message
- `app/views/searches/_flight_card.html.erb` — score label, price/comfort/trip-fit breakdown labels, total label, "Search this flight:" label, Google Flights, Skyscanner
- `app/views/search_history/index.html.erb` — title, empty state, new search link

Add new keys to both locale files as you encounter strings not covered above.

- [ ] **Step 5: Run full suite — expect green**

```bash
bundle exec rspec
```

Fix any `I18n::MissingTranslationData` errors by adding the missing key to both YAML files.

- [ ] **Step 6: Commit**

```bash
git add config/locales/ app/presenters/ app/views/
git commit -m "feat: extract all UI strings to I18n locale files (en + pt-BR)"
```

---

## Task 10: Profile Locale Selector

**Files:**
- Modify: `app/views/profile/show.html.erb`
- Modify: `app/controllers/profile_controller.rb`
- Modify: `spec/requests/profile_spec.rb`

- [ ] **Step 1: Add locale selector to `app/views/profile/show.html.erb`**

Inside the profile form, add:

```erb
<div>
  <%= f.label :preferred_locale, t("profile.locale_label"),
        class: "block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5" %>
  <%= f.select :preferred_locale,
        options_for_select([
          ["English (USD)", "en"],
          ["Português BR (BRL)", "pt-BR"]
        ], current_user.preferred_locale),
        { include_blank: t("profile.locale_auto") },
        class: "w-full bg-white rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" %>
</div>
```

- [ ] **Step 2: Permit `preferred_locale` in `ProfileController`**

Find the strong params method in `app/controllers/profile_controller.rb` and add `:preferred_locale` to the permitted list.

- [ ] **Step 3: Add request spec example**

In `spec/requests/profile_spec.rb`:

```ruby
it "saves preferred_locale to the user" do
  patch profile_path, params: { user: { preferred_locale: "pt-BR" } }
  expect(response).to redirect_to(profile_path)
  expect(user.reload.preferred_locale).to eq("pt-BR")
end

it "rejects unsupported locale" do
  patch profile_path, params: { user: { preferred_locale: "fr" } }
  expect(user.reload.preferred_locale).not_to eq("fr")
end
```

- [ ] **Step 4: Run profile spec**

```bash
bundle exec rspec spec/requests/profile_spec.rb
```

- [ ] **Step 5: Run full suite — final green**

```bash
bundle exec rspec
```

- [ ] **Step 6: Run linter**

```bash
bin/rubocop
```
Fix any offenses.

- [ ] **Step 7: Final commit**

```bash
git add app/views/profile/ app/controllers/profile_controller.rb spec/requests/profile_spec.rb
git commit -m "feat: add locale selector to profile — users can set preferred language and currency"
```
