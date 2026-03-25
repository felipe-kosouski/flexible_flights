# Rate Limiting — Design Spec (2026-03-24)

## Problem

The application has no HTTP-layer rate limiting. Without it:

- Login and signup endpoints are open to brute force and credential stuffing
- Authenticated users can flood the search form, polluting the job queue and creating noise in the database (even though the credit system gates Amadeus execution)

The credit system protects Amadeus API quota per user but does not protect the HTTP layer or the job queue from rapid-fire requests.

## Goal

Add Rack::Attack with minimal rules that cover the real threat surface for a solo-dev MVP:

1. Auth endpoint abuse (login brute force, account farming via signup)
2. Job queue pollution from rapid search submissions

## Non-Goals

- Global Amadeus quota throttle (the credit system is sufficient for MVP)
- Retry/backoff in the Sampler on `Flights::RateLimitError`
- Redis or any new infrastructure
- Custom error pages for throttled responses

---

## Architecture

### Gem

Add `rack-attack` to the Gemfile (no version pin needed — latest stable).

### Middleware

Register in `config/application.rb`, inserted before `ActionDispatch::RemoteIp` to make ordering explicit:

```ruby
config.middleware.insert_before ActionDispatch::RemoteIp, Rack::Attack
```

### Cache Backend

```ruby
Rack::Attack.cache.store = Rails.cache
```

- Development/test: `:memory_store`
- Production: Solid Cache on Postgres (`flexible_flights_production_cache` database)

No Redis. Works for single-process today; already process-safe via Postgres if processes are added later.

### Files Changed

| File | Change |
|------|--------|
| `Gemfile` | Add `gem "rack-attack"` |
| `config/application.rb` | Register middleware |
| `config/initializers/rack_attack.rb` | All throttle rules |
| `config/environments/test.rb` | `Rack::Attack.enabled = false` |
| `spec/requests/rack_attack_spec.rb` | New request spec |

---

## Throttle Rules

### 1. Login by IP

```ruby
throttle("logins/ip", limit: 10, period: 20.seconds) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end
```

Prevents automated login attempts from a single IP.

### 2. Login by Email

```ruby
throttle("logins/email", limit: 5, period: 20.seconds) do |req|
  if req.path == "/users/sign_in" && req.post?
    req.params.dig("user", "email")&.downcase&.strip
  end
end
```

Tighter limit per email to prevent targeting specific accounts across multiple IPs.

### 3. Signup by IP

```ruby
throttle("signups/ip", limit: 5, period: 60.seconds) do |req|
  req.ip if req.path == "/users" && req.post?
end
```

Prevents account farming (e.g., creating many accounts to exploit the 1 free search per account).

### 4. Search Creation by User

```ruby
throttle("searches/user", limit: 3, period: 60.seconds) do |req|
  if req.path == "/searches" && req.post?
    req.env["rack.session"]&.dig("warden.user.user.key", 0, 0)
  end
end
```

Prevents job queue flooding from a single authenticated user. Key is extracted from the Warden session via `rack.session` at the Rack layer — no ActiveRecord load. `dig(0, 0)` is explicit about Warden's `[[id], salt]` storage shape and returns `nil` cleanly if the structure is absent.

**Middleware/session ordering note:** Rack::Attack is inserted before `ActionDispatch::RemoteIp`, which is before `ActionDispatch::Session::CookieStore` in the stack. However, `rack.session` is readable at this position because `CookieStore` decodes the session cookie during the request's inbound phase before the app runs — by the time throttle blocks execute, the cookie has already been decoded into `rack.session`. This should be verified with a real login-then-throttle integration test during implementation.

**Limit rationale:** 3 searches/60s is generous. A real user cannot submit faster than this given a search takes several seconds to execute. Goal is noise prevention, not usage restriction.

---

## Response on Throttle

Default Rack::Attack behavior: `429 Too Many Requests` with `text/plain` body `"Retry later\n"`. No custom error pages for MVP.

**Turbo UX note:** The app uses Turbo for form submissions. A plain-text 429 will not render gracefully in Turbo — the browser receives the response but Turbo won't display it. This is an acceptable UX gap for MVP. Post-launch, this can be addressed by returning a Turbo Stream response or a redirect with a flash message.

---

## Testing

File: `spec/requests/rack_attack_spec.rb`

Rack::Attack is disabled globally in the test environment. The spec re-enables it per-example and assigns a fresh `MemoryStore` instance. `MemoryStore` allows counters to accumulate within a single example (required for 429 to fire), while a fresh instance per example ensures no counter state bleeds between examples.

**Note:** Do not use `NullStore` here — it discards all writes, so counters never accumulate and 429 assertions will never pass.

```ruby
before do
  @original_store = Rack::Attack.cache.store
  Rack::Attack.enabled = true
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end

after do
  Rack::Attack.enabled = false
  Rack::Attack.cache.store = @original_store
end
```

Four describe blocks — one per rule. Each test drives requests up to the limit and asserts `429` on the next one. No mocking of domain or DB — throttled requests never reach the controller.

---

## What This Does Not Change

- Existing credit system and Amadeus error handling — untouched
- Domain layer — untouched
- No new database migrations
- No changes to existing specs
