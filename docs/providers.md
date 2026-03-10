# Provider Integration Plan

## Overview

Providers are the infrastructure layer that fetches raw flight data from external APIs. They sit outside the domain and are injected into the pipeline at the job boundary.

This document covers the architecture, the Amadeus integration, and the conventions for adding future providers.

---

## Layering

```
SearchRunJob
  → resolves provider by name via Registry
  → passes provider instance to SearchRunRepository
      → SearchRunFactory (domain boundary)
          → Sampling::Runner → Sampler
              → provider.search(...)   ← only touch point with providers
```

Providers live in `app/providers/` — they make HTTP calls and have side effects, which the domain must never contain.

The domain's only knowledge of providers is the method signature: `search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)` returning `Array<Hash>`.

---

## File Layout

```
app/
└── providers/
    └── flights/
        ├── base.rb              # Abstract interface + shared error hierarchy
        ├── stub.rb              # Deterministic stub for tests and dev
        ├── registry.rb          # Name → provider instance resolution
        └── amadeus/
            ├── client.rb        # Faraday connection + OAuth2 token management
            ├── normalizer.rb    # Raw API response → canonical flight hash
            └── provider.rb      # Implements Base interface; orchestrates client + normalizer

spec/
└── providers/
    └── flights/
        ├── stub_spec.rb
        ├── registry_spec.rb
        └── amadeus/
            ├── client_spec.rb       # WebMock-based
            ├── normalizer_spec.rb   # Pure Ruby, fixture-based
            └── provider_spec.rb     # WebMock end-to-end
```

---

## Base Class

Defines the provider contract and shared error hierarchy. All adapters inherit from this.

```ruby
# app/providers/flights/base.rb
module Providers
  module Flights
    class Base
      Error           = Class.new(StandardError)
      TimeoutError    = Class.new(Error)
      RateLimitError  = Class.new(Error)
      InvalidResponse = Class.new(Error)
      AuthError       = Class.new(Error)

      def search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
        raise NotImplementedError, "#{self.class}#search is not implemented"
      end
    end
  end
end
```

All provider errors bubble up through this hierarchy. Callers (`Sampler`, `Runner`) only need to rescue `Providers::Flights::Error` to catch anything a provider can raise.

---

## Stub

A deterministic, configuration-free provider for domain specs, development seeds, and CI runs without real credentials.

```ruby
# app/providers/flights/stub.rb
module Providers
  module Flights
    class Stub < Base
      def search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
        [
          {
            price_cents:          15000,
            currency:             "EUR",
            airline_codes:        ["IB"],
            stops:                0,
            air_time_minutes:     120,
            layover_time_minutes: 0,
            luggage_included:     false,
            raw_provider:         "stub"
          },
          {
            price_cents:          22000,
            currency:             "EUR",
            airline_codes:        ["VY", "FR"],
            stops:                1,
            air_time_minutes:     180,
            layover_time_minutes: 60,
            luggage_included:     true,
            raw_provider:         "stub"
          }
        ]
      end
    end
  end
end
```

---

## Registry

Resolves a provider name (string) to a provider instance. This is the piece that fixes the ActiveJob serialization problem — jobs store a string, not a Ruby object.

```ruby
# app/providers/flights/registry.rb
module Providers
  module Flights
    class Registry
      PROVIDERS = {
        "stub"    => -> { Stub.new },
        "amadeus" => -> { Amadeus::Provider.new }
      }.freeze

      def self.resolve(name)
        factory = PROVIDERS[name] or raise ArgumentError, "Unknown provider: #{name.inspect}"
        factory.call
      end
    end
  end
end
```

---

## Job Signature Change

The current `SearchRunJob` accepts `provider:` (a Ruby object), which cannot be serialized by ActiveJob when enqueuing. Change the parameter to `provider_name:` (a string) and resolve it inside the job.

**Before:**

```ruby
def perform(search_run_id, provider:, ...)
```

**After:**

```ruby
def perform(search_run_id, provider_name: "stub", max_candidates: 20, passengers: 1, cabin_class: :economy)
  provider = Providers::Flights::Registry.resolve(provider_name)
  search_run_record = SearchRun.find(search_run_id)
  Search::Repositories::SearchRunRepository.execute(search_run_record, provider: provider, ...)
end
```

Enqueuing becomes:

```ruby
SearchRunJob.perform_later(search_run.id, provider_name: "amadeus")
```

---

## Amadeus Integration

### Authentication

Amadeus uses OAuth2 client credentials (no per-request refresh, tokens last ~30 minutes).

- **Token endpoint:** `POST /v1/security/oauth2/token`
  - Body: `grant_type=client_credentials&client_id=XXX&client_secret=YYY`
  - Response: `{ "access_token": "...", "expires_in": 1799 }`
- Token must be cached in-process and refreshed before expiry. No external cache needed for MVP.

### Search Endpoint

- **Endpoint:** `GET /v2/shopping/flight-offers`
- **Base URL (test):** `https://test.api.amadeus.com`
- **Base URL (production):** `https://api.amadeus.com`

**Parameters:**

| Our param        | Amadeus param             | Notes                            |
| ---------------- | ------------------------- | -------------------------------- |
| `origin`         | `originLocationCode`      | IATA airport code                |
| `destination`    | `destinationLocationCode` | IATA airport code                |
| `departure_date` | `departureDate`           | `YYYY-MM-DD`                     |
| `return_date`    | `returnDate`              | `YYYY-MM-DD`                     |
| `passengers`     | `adults`                  | Integer                          |
| `cabin_class`    | `travelClass`             | `:economy` → `"ECONOMY"` etc.    |
| —                | `max`                     | Hard-coded to `10` for MVP       |
| —                | `currencyCode`            | `"EUR"` (configurable if needed) |

**Cabin class mapping:**

```ruby
CABIN_CLASS_MAP = {
  economy:  "ECONOMY",
  business: "BUSINESS",
  first:    "FIRST"
}.freeze
```

---

### Client (`Amadeus::Client`)

Owns the Faraday connection, token lifecycle, and raw HTTP communication.

```ruby
# app/providers/flights/amadeus/client.rb
module Providers
  module Flights
    module Amadeus
      class Client
        BASE_URLS = {
          test:       "https://test.api.amadeus.com",
          production: "https://api.amadeus.com"
        }.freeze

        TOKEN_EXPIRY_BUFFER_SECONDS = 60

        def initialize(client_id:, client_secret:, env: :test)
          @client_id     = client_id
          @client_secret = client_secret
          @base_url      = BASE_URLS.fetch(env)
          @token         = nil
          @token_expires_at = Time.now
        end

        def flight_offers(params)
          response = connection.get("/v2/shopping/flight-offers") do |req|
            req.headers["Authorization"] = "Bearer #{fetch_token}"
            req.params = params
          end
          response.body
        rescue Faraday::TimeoutError
          raise Flights::TimeoutError, "Amadeus request timed out"
        rescue Faraday::UnauthorizedError
          raise Flights::AuthError, "Amadeus authentication failed"
        rescue Faraday::TooManyRequestsError
          raise Flights::RateLimitError, "Amadeus rate limit reached"
        rescue Faraday::Error => e
          raise Flights::Error, "Amadeus request failed: #{e.message}"
        end

        private

        def fetch_token
          refresh_token! if token_expired?
          @token
        end

        def token_expired?
          Time.now >= @token_expires_at - TOKEN_EXPIRY_BUFFER_SECONDS
        end

        def refresh_token!
          response = auth_connection.post("/v1/security/oauth2/token",
            "grant_type=client_credentials&client_id=#{@client_id}&client_secret=#{@client_secret}"
          )
          @token = response.body["access_token"]
          @token_expires_at = Time.now + response.body["expires_in"].to_i
        rescue Faraday::Error => e
          raise Flights::AuthError, "Amadeus token fetch failed: #{e.message}"
        end

        def connection
          @connection ||= Faraday.new(url: @base_url, request: { timeout: 10 }) do |f|
            f.response :json
            f.response :raise_error
            f.adapter  :net_http
          end
        end

        def auth_connection
          @auth_connection ||= Faraday.new(url: @base_url, request: { timeout: 10 }) do |f|
            f.headers["Content-Type"] = "application/x-www-form-urlencoded"
            f.response :json
            f.response :raise_error
            f.adapter  :net_http
          end
        end
      end
    end
  end
end
```

**Key decisions:**

- Token cached as instance variables on the `Client` — simple, no external cache, fits MVP.
- 60-second buffer before actual expiry prevents race conditions on long-running batches.
- Two Faraday connections: one for auth (form-encoded), one for API (JSON).
- All Faraday errors are rescued and re-raised as `Providers::Flights::*` — callers never see Faraday directly.

---

### Normalizer (`Amadeus::Normalizer`)

Converts a raw Amadeus flight offer hash into the canonical flight hash. This is a pure transformation — no HTTP, no state.

**Canonical output shape** (matches `Sampler::REQUIRED_KEYS`):

```ruby
{
  price_cents:          Integer,   # grandTotal in cents
  currency:             String,    # e.g. "EUR"
  airline_codes:        Array,     # unique carrier codes from outbound itinerary
  stops:                Integer,   # total stops across both legs
  air_time_minutes:     Integer,   # sum of all segment flight times
  layover_time_minutes: Integer,   # total duration minus air time
  luggage_included:     Boolean,   # true if any checked bag included
  raw_provider:         "amadeus"
}
```

**Field-by-field mapping from Amadeus response:**

| Canonical field        | Source in Amadeus JSON                                                                                        |
| ---------------------- | ------------------------------------------------------------------------------------------------------------- |
| `price_cents`          | `(offer["price"]["grandTotal"].to_f * 100).round`                                                             |
| `currency`             | `offer["price"]["currency"]`                                                                                  |
| `airline_codes`        | `offer["itineraries"][0]["segments"].map { \|s\| s["carrierCode"] }.uniq`                                     |
| `stops`                | sum of `(segments.size - 1)` across both itineraries                                                          |
| `air_time_minutes`     | sum of segment-level durations (arrival - departure in minutes for each segment)                              |
| `layover_time_minutes` | total itinerary duration - air_time_minutes                                                                   |
| `luggage_included`     | `travelerPricings[0]["fareDetailsBySegment"].any? { \|s\| s.dig("includedCheckedBags","quantity").to_i > 0 }` |
| `raw_provider`         | `"amadeus"` (literal)                                                                                         |

**ISO 8601 duration parsing:**

Amadeus returns itinerary durations as ISO 8601 strings (e.g. `"PT2H30M"`, `"PT45M"`, `"P1DT3H"`). Ruby stdlib has no parser for this format, so we implement a small helper:

```ruby
def parse_iso_duration_minutes(iso)
  days    = iso[/(\d+)D/, 1].to_i
  hours   = iso[/(\d+)H/, 1].to_i
  minutes = iso[/(\d+)M/, 1].to_i
  days * 1440 + hours * 60 + minutes
end
```

**Layover calculation:**

```
layover_time_minutes = total_itinerary_duration - air_time_minutes
```

where `total_itinerary_duration` comes from parsing `itineraries[i]["duration"]` and `air_time_minutes` is summed from each segment's actual departure→arrival interval.

---

### Provider (`Amadeus::Provider`)

Thin orchestrator: takes a search request, calls `Client#flight_offers`, passes raw results to `Normalizer`, returns normalized array.

```ruby
# app/providers/flights/amadeus/provider.rb
module Providers
  module Flights
    module Amadeus
      class Provider < Flights::Base
        CABIN_CLASS_MAP = {
          economy:  "ECONOMY",
          business: "BUSINESS",
          first:    "FIRST"
        }.freeze

        MAX_RESULTS = 10

        def initialize
          @client = Client.new(
            client_id:     ENV.fetch("AMADEUS_CLIENT_ID"),
            client_secret: ENV.fetch("AMADEUS_CLIENT_SECRET"),
            env:           ENV.fetch("AMADEUS_ENV", "test").to_sym
          )
        end

        def search(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
          raw = @client.flight_offers(
            originLocationCode:      origin,
            destinationLocationCode: destination,
            departureDate:           departure_date.iso8601,
            returnDate:              return_date.iso8601,
            adults:                  passengers,
            travelClass:             CABIN_CLASS_MAP.fetch(cabin_class),
            max:                     MAX_RESULTS
          )

          offers = raw["data"] || []
          offers.filter_map { |offer| Normalizer.call(offer) }
        end
      end
    end
  end
end
```

`Normalizer.call` returns `nil` for any offer that fails normalization — `filter_map` drops those silently, consistent with the sampling spec (§7.2: invalid results are dropped, not raised).

---

## Configuration

Three environment variables are required:

| Variable                | Purpose                              | Default  |
| ----------------------- | ------------------------------------ | -------- |
| `AMADEUS_CLIENT_ID`     | OAuth2 client ID from Amadeus portal | —        |
| `AMADEUS_CLIENT_SECRET` | OAuth2 client secret                 | —        |
| `AMADEUS_ENV`           | `"test"` or `"production"`           | `"test"` |

Store via Rails credentials or a `.env` file (not committed). For CI, use environment-level secrets.

---

## Testing Approach

### No live HTTP in specs — ever.

All HTTP is stubbed with `WebMock`. No VCR cassettes (they drift; fixture files are explicit and reviewable).

| Spec file            | Tests                                   | Technique                     |
| -------------------- | --------------------------------------- | ----------------------------- |
| `normalizer_spec.rb` | Field-by-field output correctness       | Pure Ruby, fixture hash input |
| `client_spec.rb`     | Token fetch, token cache, flight_offers | WebMock                       |
| `provider_spec.rb`   | Full search() call, normalizer wired in | WebMock                       |
| `stub_spec.rb`       | Returns valid canonical shape           | Pure Ruby                     |
| `registry_spec.rb`   | Resolves known names, raises on unknown | Pure Ruby                     |

**Fixture approach for `normalizer_spec.rb`:**

Keep a minimal but realistic Amadeus response hash in `spec/fixtures/amadeus/flight_offer.rb` (or inline in the spec). Each normalizer test exercises one field mapping. This way, normalizer specs never break when WebMock setup changes.

**Add to test gems:**

```ruby
group :test do
  gem "webmock"
end
```

---

## Implementation Steps (Ordered)

1. **Add gems** — `faraday` (runtime), `webmock` (test group) to `Gemfile`; `bundle install`.
2. **`Providers::Flights::Base`** — interface + error hierarchy.
3. **`Providers::Flights::Stub`** — deterministic stub formalizing current behavior.
4. **`Providers::Flights::Registry`** — name resolution; spec covering known/unknown names.
5. **Update `SearchRunJob`** — `provider_name:` string param, resolve via registry; update spec.
6. **`Amadeus::Client`** — Faraday connection, token lifecycle, `flight_offers` method; WebMock spec.
7. **`Amadeus::Normalizer`** — all field mappings + ISO duration parser; fixture-based spec.
8. **`Amadeus::Provider`** — orchestrates client + normalizer; WebMock end-to-end spec.
9. **Smoke test** — `SearchRunJob.perform_now(id, provider_name: "amadeus")` against Amadeus test environment.

---

## Adding a Second Provider (Future Pattern)

1. Create `app/providers/flights/<name>/provider.rb` inheriting from `Flights::Base`.
2. Add normalizer and client under the same namespace.
3. Register in `Registry::PROVIDERS` with a string key.
4. Enqueue with `provider_name: "<name>"`.

No changes required to the domain, repository, factory, or job signature.
