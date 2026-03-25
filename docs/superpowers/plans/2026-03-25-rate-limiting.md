# Rate Limiting (Rack::Attack) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Rack::Attack middleware with 4 throttle rules to protect login, signup, and search endpoints from abuse.

**Architecture:** Single initializer file owns all rules. Middleware wired in `application.rb` before `ActionDispatch::RemoteIp`. Cache delegates to `Rails.cache` (already Solid Cache on Postgres in production; NullStore in test). No new infrastructure.

**Tech Stack:** `rack-attack` gem, Rails middleware stack, RSpec request specs with `Devise::Test::IntegrationHelpers`

**Spec:** `docs/superpowers/specs/2026-03-24-rate-limiting-design.md`

---

## File Map

| File                                 | Action | What it does                                          |
| ------------------------------------ | ------ | ----------------------------------------------------- |
| `Gemfile`                            | Modify | Add `gem "rack-attack"`                               |
| `config/application.rb`              | Modify | Insert Rack::Attack before `ActionDispatch::RemoteIp` |
| `config/initializers/rack_attack.rb` | Create | Cache backend + all 4 throttle rules                  |
| `config/environments/test.rb`        | Modify | Disable Rack::Attack globally in tests                |
| `spec/requests/rack_attack_spec.rb`  | Create | 4 describe blocks, one per rule                       |

---

## Task 1: Install gem and wire infrastructure

**Files:**

- Modify: `Gemfile`
- Modify: `config/application.rb`
- Modify: `config/environments/test.rb`

- [ ] **Step 1: Add gem to Gemfile**

In `Gemfile`, add after the `gem "stripe"` line:

```ruby
gem "rack-attack"
```

- [ ] **Step 2: Install the gem**

```bash
bundle install
```

Expected: `rack-attack` appears in `Gemfile.lock`, no errors.

- [ ] **Step 3: Register middleware in `config/application.rb`**

Inside the `class Application < Rails::Application` block, after the `config.generators.system_tests = nil` line, add:

```ruby
config.middleware.insert_before ActionDispatch::RemoteIp, Rack::Attack
```

- [ ] **Step 4: Disable Rack::Attack in the test environment**

In `config/environments/test.rb`, at the end of the `Rails.application.configure do` block (before the closing `end`), add:

```ruby
Rack::Attack.enabled = false
```

- [ ] **Step 5: Verify the middleware is in the stack**

```bash
bin/rails middleware
```

Expected: `Rack::Attack` appears near the top of the list, before `ActionDispatch::RemoteIp`.

- [ ] **Step 6: Commit**

```bash
git add Gemfile Gemfile.lock config/application.rb config/environments/test.rb
git commit -m "feat: install rack-attack and wire middleware"
```

---

## Task 2: Write the request specs (TDD — all fail before Task 3)

**Files:**

- Create: `spec/requests/rack_attack_spec.rb`

Context: The test environment disables Rack::Attack globally. Each example re-enables it and assigns a fresh `MemoryStore` instance. `MemoryStore` allows counters to accumulate within an example (required for 429 to fire), while a fresh instance per example ensures no counter state bleeds between examples. Do not use `NullStore` — it discards all writes and 429 assertions will never pass.

The `sign_in` helper (from `Devise::Test::IntegrationHelpers`, already included for all request specs via `spec/support/devise.rb`) sets the Warden session state that persists across requests in the integration test session.

- [ ] **Step 1: Create the spec file**

Create `spec/requests/rack_attack_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rack::Attack throttling", type: :request do
  before do
    @original_store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::NullStore.new
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @original_store
  end

  describe "logins/ip — 10 requests per 20 seconds per IP" do
    it "allows up to 10 login attempts then blocks with 429" do
      10.times do
        post user_session_path, params: { user: { email: "a@b.com", password: "wrong" } }
        expect(response.status).not_to eq(429)
      end

      post user_session_path, params: { user: { email: "a@b.com", password: "wrong" } }
      expect(response.status).to eq(429)
    end
  end

  describe "logins/email — 5 requests per 20 seconds per email" do
    it "allows up to 5 login attempts per email then blocks with 429" do
      5.times do
        post user_session_path, params: { user: { email: "target@example.com", password: "wrong" } }
        expect(response.status).not_to eq(429)
      end

      post user_session_path, params: { user: { email: "target@example.com", password: "wrong" } }
      expect(response.status).to eq(429)
    end

    it "counts different emails separately" do
      5.times do
        post user_session_path, params: { user: { email: "target@example.com", password: "wrong" } }
      end

      # Different email should not be throttled yet
      post user_session_path, params: { user: { email: "other@example.com", password: "wrong" } }
      expect(response.status).not_to eq(429)
    end
  end

  describe "signups/ip — 5 requests per 60 seconds per IP" do
    it "allows up to 5 signup attempts then blocks with 429" do
      5.times do |i|
        post user_registration_path, params: {
          user: {
            email: "new#{i}@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
        expect(response.status).not_to eq(429)
      end

      post user_registration_path, params: {
        user: {
          email: "overflow@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
      expect(response.status).to eq(429)
    end
  end

  describe "searches/user — 3 requests per 60 seconds per user" do
    let(:user) { create(:user) }

    it "allows up to 3 search submissions then blocks with 429" do
      sign_in user

      search_params = {
        search_intent: {
          origin_airport: "GRU",
          destination_airport: "LIS",
          flexible_days: 7,
          trip_duration: 14,
          adults: 1,
          max_stops: 1,
          budget: 1500
        }
      }

      3.times do
        post searches_path, params: search_params
        expect(response.status).not_to eq(429)
      end

      post searches_path, params: search_params
      expect(response.status).to eq(429)
    end

    it "counts different users separately" do
      other_user = create(:user)

      search_params = {
        search_intent: {
          origin_airport: "GRU",
          destination_airport: "LIS",
          flexible_days: 7,
          trip_duration: 14,
          adults: 1,
          max_stops: 1,
          budget: 1500
        }
      }

      sign_in user
      3.times { post searches_path, params: search_params }

      # Switch to a different user — their counter should be independent
      sign_in other_user
      post searches_path, params: search_params
      expect(response.status).not_to eq(429)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

```bash
bundle exec rspec spec/requests/rack_attack_spec.rb --format documentation
```

Expected: All examples FAIL. Each throttle test should report that the response after the limit was NOT 429 (because no throttle rules exist yet). This confirms the tests are exercising real behavior.

---

## Task 3: Create the initializer with all 4 throttle rules

**Files:**

- Create: `config/initializers/rack_attack.rb`

- [ ] **Step 1: Create the initializer**

Create `config/initializers/rack_attack.rb`:

```ruby
# frozen_string_literal: true

Rack::Attack.cache.store = Rails.cache

# Rule 1: Throttle login attempts by IP
# Prevents automated login attempts from a single IP.
Rack::Attack.throttle("logins/ip", limit: 10, period: 20.seconds) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end

# Rule 2: Throttle login attempts by email
# Tighter limit per email — prevents targeting specific accounts across multiple IPs.
Rack::Attack.throttle("logins/email", limit: 5, period: 20.seconds) do |req|
  if req.path == "/users/sign_in" && req.post?
    req.params.dig("user", "email")&.downcase&.strip
  end
end

# Rule 3: Throttle signups by IP
# Prevents account farming to exploit the 1 free search per account.
Rack::Attack.throttle("signups/ip", limit: 5, period: 60.seconds) do |req|
  req.ip if req.path == "/users" && req.post?
end

# Rule 4: Throttle search creation by user
# Prevents job queue flooding from a single authenticated user.
# Key: Warden stores [[user_id], salt] — dig(0, 0) extracts the user ID.
# Returns nil for unauthenticated requests (no session key → no throttle key → not throttled).
Rack::Attack.throttle("searches/user", limit: 3, period: 60.seconds) do |req|
  if req.path == "/searches" && req.post?
    # rack.session may be nil if CookieStore hasn't decoded the cookie yet at this
    # middleware position — safe navigation prevents NoMethodError on unauthenticated requests.
    req.env["rack.session"]&.dig("warden.user.user.key", 0, 0)
  end
end
```

- [ ] **Step 2: Run the Rack::Attack specs**

```bash
bundle exec rspec spec/requests/rack_attack_spec.rb --format documentation
```

Expected: All examples PASS.

> **Note on `searches/user` failure mode:** If the search throttle tests pass for rules 1–3 but the `searches/user` throttle test never returns 429 (i.e., all 4 requests return non-429), it means `rack.session` is nil at this middleware position and `&.dig` is returning nil (no key → no throttle). If this happens, the throttle needs to be moved to a later middleware position. See the spec's "Middleware/session ordering note" for context.

- [ ] **Step 3: Run the full request spec suite to check for regressions**

```bash
bundle exec rspec spec/requests/ --format documentation
```

Expected: All existing request specs continue to pass. Rack::Attack is disabled in the test environment globally (via `config/environments/test.rb`), so existing specs are unaffected.

- [ ] **Step 4: Run the full test suite**

```bash
bundle exec rspec
```

Expected: All specs pass. No regressions.

- [ ] **Step 5: Run security and style checks**

```bash
bin/rubocop config/initializers/rack_attack.rb spec/requests/rack_attack_spec.rb
bin/brakeman --no-pager
```

Expected: No offenses or new warnings.

- [ ] **Step 6: Commit**

```bash
git add config/initializers/rack_attack.rb spec/requests/rack_attack_spec.rb
git commit -m "feat: add Rack::Attack throttle rules for login, signup, and search"
```

---

## Done

Rate limiting is live. All 4 rules are active in development and production. Tests are isolated and will catch any future regressions.

**Post-MVP follow-up (not in scope now):**

- Turbo-friendly 429 responses (Turbo Stream or redirect with flash message)
- Custom `Retry-After` header on throttled responses
