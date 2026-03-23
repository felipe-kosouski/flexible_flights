# Payment System Design (Stripe Checkout + Search Packs)

**Date:** 2026-03-19
**Status:** Approved
**Scope:** MVP — one-time search pack purchases via Stripe Checkout with USD/BRL pricing

---

## 1. Overview

Flexible Flights monetises through search packs — users buy a fixed number of smart searches. The system uses Stripe Checkout (hosted page) for payment, stores a credit balance on the `users` table, and gates search execution at the controller layer.

**Key decisions:**

- Credits model (not trial flag) — unified system for free grants and purchases
- Deduct on success only — failed searches do not cost credits
- Gate at submission — controller checks credits before enqueuing the job
- Stripe Checkout (hosted) — fastest path, Stripe handles all payment UI and PCI compliance
- Fixed local prices — separate USD and BRL Price objects in Stripe, not dynamic conversion
- Dynamic payment methods — Stripe auto-shows PIX for Brazilian users
- DB `CHECK (search_credits >= 0)` constraint — defense-in-depth against concurrent race conditions

---

## 2. Pack Tiers & Pricing

| Pack key  | Credits | USD price | BRL price |
| --------- | ------- | --------- | --------- |
| `pack_5`  | 5       | $2.99     | R$14,90   |
| `pack_15` | 15      | $7.99     | R$39,90   |
| `pack_30` | 30      | $14.99    | R$74,90   |

BRL prices are set slightly below PPP parity. They are fixed (not dynamically converted) and reviewed annually when exchange rates shift significantly.

**Payment methods enabled in Stripe Dashboard:**

- Cards (all locales)
- PIX (Brazil — instant settlement, dominant local method)
- Boleto: **off for MVP** (3-day settlement adds fulfillment complexity)

---

## 3. Architecture

### Dependencies

Add to `Gemfile`:

```ruby
gem "stripe"
```

Stripe API key configured in `config/initializers/stripe.rb`:

```ruby
Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
```

Webhook secret and any future Stripe configuration accessed via `StripeConfig` in `app/support/stripe_config.rb` — consistent with existing support classes (`CurrencyResolver`, `LocaleResolver`):

```ruby
class StripeConfig
  def self.webhook_secret
    ENV.fetch("STRIPE_WEBHOOK_SECRET")
  end
end
```

Controllers call `StripeConfig.webhook_secret` — no raw `ENV` reads outside the config class.

### New components

| Component                        | Layer      | Responsibility                                        |
| -------------------------------- | ---------- | ----------------------------------------------------- |
| `users.search_credits` (integer) | AR model   | Credit balance. Default: 1 (free grant on sign-up)    |
| `CreditPurchase` AR model        | AR model   | Idempotent record of each fulfilled Stripe checkout   |
| `PaymentsController`             | Controller | Creates Checkout Sessions, renders purchase page      |
| `StripeWebhooksController`       | Controller | Receives `checkout.session.completed`, grants credits |
| `SearchesController` (modified)  | Controller | Gates search submission on credit balance             |
| `SearchRunJob` (modified)        | Job        | Decrements credit after successful repository call    |
| `StripeConfig` support class     | Support    | Centralises Stripe configuration (webhook secret)     |

Note: credit decrement lives in `SearchRunJob` (after a successful `SearchRunRepository.execute` call), **not** inside the repository. The repository owns the search transaction; the job owns the post-execution side effect. This preserves the repository's single responsibility.

### Data flow

```
Purchase flow:
User clicks "Buy" → PaymentsController#create → Stripe::Checkout::Session.create
→ Redirect to Stripe hosted page → User pays (card / PIX)
→ Stripe fires checkout.session.completed webhook
→ StripeWebhooksController verifies signature
→ CreditPurchase.create! (idempotency guard via unique index)
→ User.update_all(["search_credits = search_credits + ?", credits_granted])

Search flow:
User submits search → SearchesController#create checks search_credits > 0
→ 0 credits: redirect to new_payment_path
→ credits ok: enqueue SearchRunJob
→ Job calls SearchRunRepository.execute (search transaction)
→ Transaction commits successfully
→ Job decrements credit: update_all("search_credits = search_credits - 1")
→ Job fails → no credit change
```

---

## 4. Database Changes

### Migration 1 — Add credits column to users

```ruby
add_column :users, :search_credits, :integer, default: 1, null: false
execute "ALTER TABLE users ADD CONSTRAINT search_credits_non_negative CHECK (search_credits >= 0)"
```

Default of 1 means every existing and future user starts with 1 free credit. No sign-up callback needed.

The `CHECK` constraint is a defense-in-depth guard: the controller gate prevents normal 0-credit submissions, but under concurrent requests (user submits two searches simultaneously before either job completes) the DB rejects any decrement that would produce a negative balance. The job rescues `ActiveRecord::StatementInvalid` on this constraint violation, logs a warning, and does not raise — the search has already completed successfully.

### Migration 2 — Create credit_purchases table

```ruby
create_table :credit_purchases do |t|
  t.references :user, null: false, foreign_key: true
  t.string :stripe_session_id, null: false
  t.string :pack_key, null: false        # "pack_5", "pack_15", "pack_30"
  t.integer :credits_granted, null: false
  t.string :currency, null: false        # "usd" or "brl"
  t.integer :amount_cents, null: false
  t.datetime :fulfilled_at, null: false
  t.timestamps
end

add_index :credit_purchases, :stripe_session_id, unique: true
```

`fulfilled_at` is set to `Time.current` when the record is created in the webhook handler. The unique index on `stripe_session_id` is the idempotency guard — Stripe retries webhooks on non-2xx responses; the unique constraint ensures duplicate deliveries produce `ActiveRecord::RecordNotUnique`, which is rescued and returns `200`.

---

## 5. Credit Lifecycle

### Grant (sign-up)

Handled by the column default. No code required.

### Gate (search submission)

`SearchesController#create` before enqueuing. `before_action :authenticate_user!` is already present on `SearchesController` — no change needed there:

```ruby
if current_user.search_credits < 1
  redirect_to new_payment_path, alert: t("payments.no_credits")
end
```

### Deduct (search success)

In `SearchRunJob#perform`, after `SearchRunRepository.execute` returns without raising. The job already has `search_run_record` in scope (resolved via `SearchRun.find(search_run_id)`); navigate the association to reach `user_id`:

```ruby
Search::Repositories::SearchRunRepository.execute(search_run_record, ...)
# only reached if execute did not raise:
User.where(id: search_run_record.search_intent.user_id)
    .update_all("search_credits = search_credits - 1")
rescue ActiveRecord::StatementInvalid => e
  Rails.logger.warn("Credit decrement skipped (constraint): #{e.message}")
end
```

The `rescue` handles the concurrent edge case where the DB `CHECK` constraint rejects a decrement to -1. The search is done; we log and move on. The atomic `update_all` (no Rails-level read-modify-write) prevents double-decrement under normal concurrency.

### Grant (purchase)

`StripeWebhooksController` on `checkout.session.completed`. `credits_granted` is looked up from `CREDIT_PACKS` using `pack_key` from metadata — it is never interpolated directly from the payload:

```ruby
pack = CREDIT_PACKS[session.metadata[:pack_key].to_sym]
credits = pack[:credits]  # trusted constant, not raw metadata

User.where(id: user_id).update_all(["search_credits = search_credits + ?", credits])
```

Using a parameterized query for the update. The value comes from the server-side `CREDIT_PACKS` constant, not directly from the webhook payload.

---

## 6. Stripe Integration

### Pack configuration

Defined in `config/initializers/stripe.rb` (loaded once at boot, always available):

```ruby
Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

CREDIT_PACKS = {
  pack_5:  { credits: 5,  usd_price_id: ENV["STRIPE_PRICE_PACK5_USD"],  brl_price_id: ENV["STRIPE_PRICE_PACK5_BRL"] },
  pack_15: { credits: 15, usd_price_id: ENV["STRIPE_PRICE_PACK15_USD"], brl_price_id: ENV["STRIPE_PRICE_PACK15_BRL"] },
  pack_30: { credits: 30, usd_price_id: ENV["STRIPE_PRICE_PACK30_USD"], brl_price_id: ENV["STRIPE_PRICE_PACK30_BRL"] }
}.freeze
```

Six environment variables (three packs × two currencies), plus `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET`. Separate values for test and production.

### Checkout Session creation (`PaymentsController#create`)

`pack_key` param is validated against `CREDIT_PACKS` keys — unknown keys return `422` before any Stripe call:

```ruby
pack_key = params[:pack_key].to_sym
pack = CREDIT_PACKS[pack_key]
return head :unprocessable_entity unless pack

currency = CurrencyResolver.for_locale(I18n.locale)  # "USD" or "BRL"
price_id = currency == "BRL" ? pack[:brl_price_id] : pack[:usd_price_id]

session = Stripe::Checkout::Session.create(
  customer_email: current_user.email,
  line_items: [{ price: price_id, quantity: 1 }],
  mode: "payment",
  success_url: payment_success_url(session_id: "{CHECKOUT_SESSION_ID}"),
  cancel_url: new_payment_url,
  metadata: { user_id: current_user.id, pack_key: pack_key }
)

redirect_to session.url, allow_other_host: true
```

No `payment_method_types` — dynamic payment methods in Stripe Dashboard handles locale-appropriate methods automatically.

### `payments#success` action

Displays a simple confirmation page. Does **not** query Stripe or trigger credit grants — fulfillment is handled exclusively by the webhook. The `session_id` query param is available for displaying an order reference to the user but is never used for business logic.

### Webhook handler (`StripeWebhooksController#create`)

`StripeWebhooksController` inherits from `ActionController::Base` directly (not `ApplicationController`) to avoid the `set_locale` before_action running on every webhook delivery.

```
1. Read raw request body + Stripe-Signature header
2. Stripe::Webhook.construct_event(payload, sig_header, StripeConfig.webhook_secret)
   → rescue Stripe::SignatureVerificationError → return 400
3. Return 200 immediately for all event types other than checkout.session.completed
4. Extract user_id and pack_key (a string, e.g. "pack_5") from session.metadata
5. Look up pack from CREDIT_PACKS[pack_key.to_sym] → return 422 if not found
   (.to_sym required because Stripe always returns metadata values as strings)
6. Find user: User.find_by(id: user_id) → log warning and return 200 if not found
7. Wrap steps 7a and 7b in a single ActiveRecord::Base.transaction:
   7a. CreditPurchase.create!(
         user: user,
         stripe_session_id: session.id,
         pack_key: pack_key,
         credits_granted: pack[:credits],
         currency: session.currency.upcase,
         amount_cents: session.amount_total,
         fulfilled_at: Time.current
       )
   7b. User.where(id: user.id).update_all(["search_credits = search_credits + ?", pack[:credits]])
   → rescue ActiveRecord::RecordNotUnique (outside transaction) → return 200
     (duplicate webhook — CreditPurchase already exists, credits already granted)
8. Return 200
```

Steps 7a and 7b are inside one transaction so a mid-flight crash cannot produce a fulfilled `CreditPurchase` record without the credits being added. The `rescue ActiveRecord::RecordNotUnique` is placed **outside** the transaction block so it catches the unique constraint violation correctly.

The webhook endpoint (`POST /stripe/webhooks`) must call `skip_before_action :verify_authenticity_token`. No Devise authentication. All security comes from the Stripe signature check.

---

## 7. Currency Selection

Locale drives currency via the existing `CurrencyResolver`:

```ruby
CurrencyResolver.for_locale(I18n.locale)  # => "USD" or "BRL"
```

| Locale  | `CurrencyResolver` output | Price object used |
| ------- | ------------------------- | ----------------- |
| `en`    | `"USD"`                   | `usd_price_id`    |
| `pt-BR` | `"BRL"`                   | `brl_price_id`    |

`I18n.locale` is already resolved by `ApplicationController#set_locale` from `user.preferred_locale` or `Accept-Language` header. If new locales are added later, `CurrencyResolver::LOCALE_CURRENCY` is the single place to extend the mapping.

---

## 8. Routes

```ruby
resources :payments, only: [:new, :create] do
  collection do
    get :success
  end
end

post "/stripe/webhooks", to: "stripe_webhooks#create"
```

---

## 9. Testing

Stripe calls are stubbed with `allow(Stripe::Checkout::Session).to receive(:create)` and `allow(Stripe::Webhook).to receive(:construct_event)` in request specs. No outbound network calls in tests.

### `StripeWebhooksController` (request spec)

- Valid `checkout.session.completed` → credits granted, `CreditPurchase` created with `fulfilled_at` set
- Duplicate webhook (same `stripe_session_id`) → no double-grant, returns `200`
- Invalid signature → returns `400`
- Unknown `pack_key` in metadata → returns `422`
- Unknown `user_id` in metadata → returns `200`, logs warning, no crash

### `PaymentsController` (request spec)

- Creates Checkout Session with BRL price when locale is `pt-BR`
- Creates Checkout Session with USD price when locale is `en`
- Unknown `pack_key` → returns `422` (no Stripe call made)
- Unauthenticated request → redirects to sign-in

### `SearchesController` (request spec — addition to existing)

- 0 credits → redirects to `new_payment_path`
- Credits > 0 → search enqueued normally

### `SearchRunJob` (addition to existing spec)

- Successful run → `search_credits` decremented by 1
- Failed run → `search_credits` unchanged
- Concurrent edge case → `ActiveRecord::StatementInvalid` rescued, no re-raise

### `User` model (unit spec)

- `search_credits` defaults to 1 on creation

No domain specs — credits are entirely outside the domain layer.

---

## 10. Out of Scope (MVP)

- Boleto payment method
- Purchase history page for users
- Refunds
- Credit expiry
- Subscription model
- Referral credits
- Admin credit management
