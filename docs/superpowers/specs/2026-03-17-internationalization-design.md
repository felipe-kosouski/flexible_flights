# Internationalization (i18n) Design

**Date:** 2026-03-17
**Status:** Approved
**Scope:** EN + PT-BR. Currency-aware pricing. AI copy translated. Clean architecture — logic extracted from controllers into dedicated support objects.

---

## Problem

- Prices are displayed with a hardcoded `$` regardless of the flight's actual currency.
- Amadeus is not passed a `currencyCode`, so it returns prices in its default market currency.
- All UI copy and AI-generated text is English-only.
- Brazilian users (and future non-English users) see a product that doesn't reflect their context.

---

## Goals

1. Detect the user's locale automatically from the browser (`Accept-Language` header).
2. Allow users to override their locale in their profile (persistent).
3. Display prices in the correct currency for the user's locale.
4. Translate all static UI copy to PT-BR via Rails I18n.
5. Translate AI-generated flight explanations and route summaries to the user's language.

---

## Non-Goals

- URL-based locale prefixes (`/pt-BR/searches`).
- More than 2 locales at this stage (EN + PT-BR only).
- Currency conversion (we request the correct currency from Amadeus directly — no conversion layer).
- RTL language support.
- Translating Rails/Devise internal validation error messages.

---

## Supported Locales

| Locale  | Language             | Currency |
| ------- | -------------------- | -------- |
| `en`    | English              | USD      |
| `pt-BR` | Brazilian Portuguese | BRL      |

---

## Architecture

### Section 1: Locale Resolution

**`LocaleResolver`** (`app/support/locale_resolver.rb`) — plain Ruby class, no Rails dependencies.

Priority order (highest to lowest):

1. User's `preferred_locale` (profile setting, persisted on `User`)
2. Session locale string (`session[:locale]`)
3. `Accept-Language` HTTP header (parsed, first supported locale wins)
4. Default: `"en"`

The resolver accepts `session_locale:` as a pre-extracted string (not the full session object) to keep the class free of Rails coupling and easy to unit-test.

Interface:

```ruby
LocaleResolver.resolve(user:, session_locale:, accept_language:) → String
```

`ApplicationController` stays thin — one before_action, three lines:

```ruby
before_action :set_locale

def set_locale
  locale = LocaleResolver.resolve(
    user: current_user,
    session_locale: session[:locale],
    accept_language: request.env["HTTP_ACCEPT_LANGUAGE"]
  )
  session[:locale] = locale
  I18n.locale = locale
end
```

All parsing and fallback logic lives in `LocaleResolver`.

---

### Section 2: Currency Resolution & Data Flow

**`CurrencyResolver`** (`app/support/currency_resolver.rb`) — plain Ruby class mapping locale → ISO 4217 currency code.

```ruby
CurrencyResolver.for_locale("pt-BR") → "BRL"
CurrencyResolver.for_locale("en")    → "USD"
```

**`PriceFormatter`** (`app/support/price_formatter.rb`) — replaces all hardcoded `"$#{cents}"` patterns across presenters and services. Supported symbols: `USD → $`, `BRL → R$`, `EUR → €`. Falls back to the ISO code string for unknown currencies.

```ruby
PriceFormatter.call(cents, currency) → "R$ 2.340" | "$536" | "N/A"
```

**Currency data flow:**

```
User locale (I18n.locale)
  → CurrencyResolver.for_locale
  → SearchIntent.currency  (stored at creation, immutable)
  → SearchRunJob → SearchRunRepository → SearchRun (domain) → SearchExecution
  → Sampling::Runner (currency_code:) → Sampling::Sampler (currency_code:)
  → provider.search(currency_code:) → Amadeus API (currencyCode: param)
  → FlightSample raw hash (currency already a REQUIRED_KEY in Sampler)
  → FlightSampleMapper → Models::FlightSample.currency
  → RankedFlightPresenter → PriceFormatter.call(cents, flight.currency)
```

Currency is captured at **search creation time** and stored on `SearchIntent`. Results always display in the currency the user searched in, even if they later change their locale.

**Architectural note on `currency_code` through the domain layer:**
Passing `currency_code` through `Sampling::Runner` and `Sampling::Sampler` is consistent with the existing pattern for `passengers` and `cabin_class` — both are search parameters that flow from the job through the domain to the provider call. `currency_code` is the same kind of parameter: it instructs the provider, carries no business logic, and is not used by any scoring or ranking domain object. This is acceptable.

**Full changes table:**

| Component                                            | Change                                                                                                                                                                                                                                                                       |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `search_intents` table                               | Add `currency` string column (`null: false, default: "USD"`)                                                                                                                                                                                                                 |
| `SearchIntent` AR model                              | Add `currency` presence validation                                                                                                                                                                                                                                           |
| `SearchIntent` domain model (`Models::SearchIntent`) | Add `currency` attribute                                                                                                                                                                                                                                                     |
| `SearchesController#create`                          | Set `currency` from `CurrencyResolver.for_locale(I18n.locale)` before saving                                                                                                                                                                                                 |
| `SearchRunFactory.from_record`                       | Add `currency_code:` keyword arg; read `search_intent.currency` from the AR record and pass to `SearchRun.new`. `SearchRunRepository.execute` requires **no signature change** — currency is sourced from the already-loaded `search_intent` association inside the factory. |
| `SearchRun` domain aggregate                         | Accept and carry `currency_code` from `SearchIntent.currency`                                                                                                                                                                                                                |
| `SearchExecution`                                    | Forward `currency_code` to `Sampling::Runner`                                                                                                                                                                                                                                |
| `Sampling::Runner`                                   | Add `currency_code:` param, forward to `Sampler`                                                                                                                                                                                                                             |
| `Sampling::Sampler`                                  | Add `currency_code:` param, pass to `provider.search`                                                                                                                                                                                                                        |
| `Flights::Base`                                      | Add optional `currency_code:` param to `search` interface                                                                                                                                                                                                                    |
| `Flights::Amadeus::Provider`                         | Pass `currencyCode:` to Amadeus API                                                                                                                                                                                                                                          |
| `Flights::Stub`                                      | Accept and ignore `currency_code:` (no change to stub data — stub continues to return `currency: "EUR"`, so price display in development will show EUR regardless of user locale; this is expected and acceptable)                                                           |
| `Models::FlightSample` (domain)                      | Add `currency` attribute (read from raw sample via mapper)                                                                                                                                                                                                                   |
| `Mappers::FlightSampleMapper`                        | Map `currency` from raw hash to domain `FlightSample`                                                                                                                                                                                                                        |
| `RankedFlightPresenter#format_price`                 | Replace with `PriceFormatter.call(flight.price_cents, flight.currency)`                                                                                                                                                                                                      |
| `ExplanationCopyService#format_price`                | Replace with `PriceFormatter.call`                                                                                                                                                                                                                                           |
| `ExplanationCopyService#price_delta_label`           | Replace hardcoded `$` with `PriceFormatter` symbol lookup                                                                                                                                                                                                                    |
| `RouteSummaryCopyService#format_price`               | Replace with `PriceFormatter.call`                                                                                                                                                                                                                                           |
| `User` model                                         | Add `preferred_locale` string column, validate against supported locales                                                                                                                                                                                                     |
| Profile UI                                           | Add locale selector (EN / PT-BR)                                                                                                                                                                                                                                             |

---

### Section 3: I18n Translation Files

Standard Rails I18n. Two locale files:

- `config/locales/en.yml`
- `config/locales/pt-BR.yml`

**What gets translated:**

- All views: labels, headings, buttons, placeholders, status messages, error copy
- Presenters: score labels (`"Excellent"`, `"Good"`), tag labels (`"Top rated"`), stops labels (`"Direct"`, `"1 stop"`), luggage labels, explanation key labels, tradeoff labels
- Hardcoded label hashes in presenters are removed in favour of `I18n.t()` calls

**Presenter pattern — before:**

```ruby
TAG_LABELS = { top_rated: "Top rated", best_price: "Best price" }.freeze

def tag_label(tag)
  TAG_LABELS[tag]
end
```

**After:**

```ruby
def tag_label(tag)
  I18n.t("flights.tags.#{tag}")
end
```

**Translation file structure (representative excerpt):**

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
  searches:
    new:
      title: "Encontre o melhor momento para voar"
      subtitle: "Vamos analisar sua janela de viagem e dizer quando ir — e se você deve reservar agora ou esperar."
      submit: "Buscar voos"
  profile:
    title: "Perfil"
    locale_label: "Idioma e moeda"
```

---

### Section 4: AI Copy Locale

**`AiLocale`** (`app/support/ai_locale.rb`) — module with a language instruction map. Shared by both AI services.

```ruby
module AiLocale
  LANGUAGE_INSTRUCTIONS = {
    "pt-BR" => "Respond in Brazilian Portuguese (PT-BR)."
  }.freeze

  # Returns nil for English (model default) — callers must guard before appending.
  def self.instruction_for(locale)
    LANGUAGE_INSTRUCTIONS[locale.to_s]
  end
end
```

`instruction_for` returns `nil` for English — this is intentional (the model defaults to English, no instruction needed). Callers must guard: `instruction = AiLocale.instruction_for(locale); system_prompt += "\n#{instruction}" if instruction`.

**Changes to both services:**

- Accept a `locale:` parameter (defaults to `I18n.locale.to_s`)
- Append `AiLocale.instruction_for(locale)` to the system prompt when non-nil
- Include locale in all cache keys

**`ExplanationCopyService` cache key specifics:**

- Instance `cache_key` method: add `locale` as a component
- `self.fingerprint_for`: add `locale` as a component (fingerprint is used as both the batch item ID and the batch cache key component — both must include locale)
- Batch cache key: inherits locale via fingerprints

**`RouteSummaryCopyService#cache_key`**: add `locale` as a component alongside existing fields.

**Service signatures:**

```ruby
# RouteSummaryCopyService
def self.call(insights:, snapshot:, intent: nil, locale: I18n.locale.to_s)

# ExplanationCopyService
def self.call(ranked_flight:, intent:, total_flights: nil, locale: I18n.locale.to_s)
def self.batch_call(ranked_flights:, intent:, total_flights:, locale: I18n.locale.to_s)
```

The AI prompt rules (e.g. `"Never use em dashes"`, output format instructions) remain in English — they are instructions to the model, not user-facing copy. Only the generated output is in the user's language.

---

## New Support Files

| File                               | Purpose                              |
| ---------------------------------- | ------------------------------------ |
| `app/support/locale_resolver.rb`   | Locale detection with priority chain |
| `app/support/currency_resolver.rb` | Locale → ISO currency code mapping   |
| `app/support/price_formatter.rb`   | Currency-aware price formatting      |
| `app/support/ai_locale.rb`         | Locale → AI language instruction     |
| `config/locales/en.yml`            | English translations                 |
| `config/locales/pt-BR.yml`         | Brazilian Portuguese translations    |

---

## Database Changes

| Migration                        | Column             | Type     | Constraint                    | Note                                                                     |
| -------------------------------- | ------------------ | -------- | ----------------------------- | ------------------------------------------------------------------------ |
| `add_currency_to_search_intents` | `currency`         | `string` | `null: false, default: "USD"` | Default backfills existing rows to USD — acceptable for a 2-locale scope |
| `add_preferred_locale_to_users`  | `preferred_locale` | `string` | `null: true`                  | Null means "use browser detection"                                       |

---

## Testing

- `LocaleResolver`: unit spec — user preference wins, session fallback, header fallback, default fallback, unsupported locale rejected, nil inputs handled
- `CurrencyResolver`: unit spec — supported locales, unknown locale falls back to `"USD"`
- `PriceFormatter`: unit spec — USD, BRL, EUR, unknown currency (uses ISO code), nil cents returns `"N/A"`
- `AiLocale`: unit spec — PT-BR returns instruction string, EN returns nil
- `Sampling::Runner` + `Sampling::Sampler`: existing specs updated to pass `currency_code:`, verify it is forwarded to provider
- `Flights::Amadeus::Provider`: existing specs updated to verify `currencyCode` appears in the Amadeus API params
- `ExplanationCopyService`: existing examples updated to pass `locale:`; new examples verify PT-BR cache key differs from EN, and system prompt contains language instruction for PT-BR
- `RouteSummaryCopyService`: same pattern as above
- Domain specs (`Models::FlightSample`): add `currency` attribute examples
- No change to scoring, ranking, analysis, or insights specs — currency does not enter those layers

---

## Out of Scope

- Translating AI prompt _rules_ (they stay in English — they instruct the model, not the user)
- Currency conversion at display time
- Adding a third locale
- Translating Rails/Devise internal validation error messages (acceptable to leave in EN for now)
