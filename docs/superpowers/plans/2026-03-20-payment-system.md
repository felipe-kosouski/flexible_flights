# Payment System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Stripe Checkout search pack purchases with USD/BRL pricing, a credit balance on users, and a credit gate on search submission.

**Architecture:** Credits are an integer column on `users` (default 1). Stripe Checkout (hosted page) handles payment UI. A `CreditPurchase` record with a unique Stripe session ID guards against duplicate webhook deliveries. Credit deduction runs in `SearchRunJob` after a successful repository call — outside the search transaction.

**Tech Stack:** `stripe` gem, Stripe Checkout Sessions API, PostgreSQL CHECK constraint, RSpec request specs with stubbed Stripe calls.

**Spec:** `docs/superpowers/specs/2026-03-19-payment-system-design.md`

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `config/initializers/stripe.rb` | API key + CREDIT_PACKS constant |
| Create | `app/support/stripe_config.rb` | Webhook secret accessor |
| Create | `db/migrate/TIMESTAMP_add_search_credits_to_users.rb` | credits column + CHECK constraint |
| Create | `db/migrate/TIMESTAMP_create_credit_purchases.rb` | purchase records table |
| Create | `app/models/credit_purchase.rb` | AR model + validations |
| Create | `app/controllers/payments_controller.rb` | Checkout Session creation + success page |
| Create | `app/controllers/stripe_webhooks_controller.rb` | Webhook handler |
| Create | `app/views/payments/new.html.erb` | Pack selection page |
| Create | `app/views/payments/success.html.erb` | Post-purchase confirmation |
| Create | `spec/lib/stripe_config_spec.rb` | StripeConfig unit spec |
| Create | `spec/models/credit_purchase_spec.rb` | CreditPurchase model spec |
| Create | `spec/factories/credit_purchases.rb` | FactoryBot factory |
| Create | `spec/requests/payments_spec.rb` | PaymentsController request spec |
| Create | `spec/requests/stripe_webhooks_spec.rb` | StripeWebhooksController request spec |
| Modify | `Gemfile` | Add `gem "stripe"` |
| Modify | `config/routes.rb` | Add payments + webhooks routes |
| Modify | `app/models/user.rb` | Add `has_many :credit_purchases` |
| Modify | `app/controllers/searches_controller.rb` | Add credit gate in `create` |
| Modify | `app/jobs/search_run_job.rb` | Add `decrement_credit` after execute |
| Modify | `spec/models/user_spec.rb` | Add `search_credits` default test |
| Modify | `spec/requests/searches_spec.rb` | Add credit gate tests |

---

## Task 1: Add Stripe gem

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add gem**

  Open `Gemfile`. After `gem "anthropic"`, add:
  ```ruby
  gem "stripe"
  ```

- [ ] **Step 2: Install**

  ```bash
  bundle install
  ```
  Expected: stripe gem installed with no errors.

---

## Task 2: Database migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_add_search_credits_to_users.rb`
- Create: `db/migrate/TIMESTAMP_create_credit_purchases.rb`

- [ ] **Step 1: Generate migrations**

  ```bash
  bin/rails generate migration AddSearchCreditsToUsers
  bin/rails generate migration CreateCreditPurchases
  ```

- [ ] **Step 2: Fill migration 1 — add credits column**

  Open the generated `*_add_search_credits_to_users.rb` and replace its body:
  ```ruby
  def change
    add_column :users, :search_credits, :integer, default: 1, null: false
    execute "ALTER TABLE users ADD CONSTRAINT search_credits_non_negative CHECK (search_credits >= 0)"
  end
  ```

- [ ] **Step 3: Fill migration 2 — create credit_purchases**

  Open the generated `*_create_credit_purchases.rb` and replace its body:
  ```ruby
  def change
    create_table :credit_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_session_id, null: false
      t.string :pack_key, null: false
      t.integer :credits_granted, null: false
      t.string :currency, null: false
      t.integer :amount_cents, null: false
      t.datetime :fulfilled_at, null: false
      t.timestamps
    end

    add_index :credit_purchases, :stripe_session_id, unique: true
  end
  ```

- [ ] **Step 4: Run migrations**

  ```bash
  bin/rails db:migrate
  ```
  Expected: Both migrations run with no errors.

---

## Task 3: User model — search_credits default

**Files:**
- Modify: `spec/models/user_spec.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Write failing test**

  Open `spec/models/user_spec.rb`. Add inside `RSpec.describe User`:
  ```ruby
  describe "search_credits" do
    it "defaults to 1 on creation" do
      user = create(:user)
      expect(user.search_credits).to eq(1)
    end

    it "has a has_many relationship with credit_purchases" do
      is_expected.to have_many(:credit_purchases)
    end
  end
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  bundle exec rspec spec/models/user_spec.rb --format documentation
  ```
  Expected: The `have_many(:credit_purchases)` example fails — association not defined yet. The `search_credits defaults to 1` example will already pass (the column default from Task 2 handles it), which is expected.

- [ ] **Step 3: Add association to User model**

  Open `app/models/user.rb`. After `has_many :search_runs, through: :search_intents`, add:
  ```ruby
  has_many :credit_purchases, dependent: :destroy
  ```

- [ ] **Step 4: Run tests to verify they pass**

  ```bash
  bundle exec rspec spec/models/user_spec.rb --format documentation
  ```
  Expected: All pass. The `search_credits` default comes from the column default — no Ruby code needed.

---

## Task 4: StripeConfig support class

**Files:**
- Create: `app/support/stripe_config.rb`
- Create: `spec/lib/stripe_config_spec.rb`

- [ ] **Step 1: Write failing test**

  Create `spec/lib/stripe_config_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe StripeConfig do
    describe ".webhook_secret" do
      it "returns the value of STRIPE_WEBHOOK_SECRET" do
        allow(ENV).to receive(:fetch).with("STRIPE_WEBHOOK_SECRET").and_return("whsec_test")
        expect(described_class.webhook_secret).to eq("whsec_test")
      end

      it "raises KeyError when STRIPE_WEBHOOK_SECRET is not set" do
        allow(ENV).to receive(:fetch).with("STRIPE_WEBHOOK_SECRET").and_call_original
        expect { described_class.webhook_secret }.to raise_error(KeyError)
      end
    end
  end
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  bundle exec rspec spec/lib/stripe_config_spec.rb --format documentation
  ```
  Expected: `NameError: uninitialized constant StripeConfig`

- [ ] **Step 3: Implement StripeConfig**

  Create `app/support/stripe_config.rb`:
  ```ruby
  class StripeConfig
    def self.webhook_secret
      ENV.fetch("STRIPE_WEBHOOK_SECRET")
    end
  end
  ```

- [ ] **Step 4: Run test to verify it passes**

  ```bash
  bundle exec rspec spec/lib/stripe_config_spec.rb --format documentation
  ```
  Expected: Both examples pass.

---

## Task 5: Stripe initializer with CREDIT_PACKS

**Files:**
- Create: `config/initializers/stripe.rb`

No automated tests for this file — it is configuration. The integration is exercised by the controller specs in later tasks.

- [ ] **Step 1: Create initializer**

  Create `config/initializers/stripe.rb`:
  ```ruby
  Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

  CREDIT_PACKS = {
    pack_5:  { credits: 5,  usd_price_id: ENV["STRIPE_PRICE_PACK5_USD"],  brl_price_id: ENV["STRIPE_PRICE_PACK5_BRL"] },
    pack_15: { credits: 15, usd_price_id: ENV["STRIPE_PRICE_PACK15_USD"], brl_price_id: ENV["STRIPE_PRICE_PACK15_BRL"] },
    pack_30: { credits: 30, usd_price_id: ENV["STRIPE_PRICE_PACK30_USD"], brl_price_id: ENV["STRIPE_PRICE_PACK30_BRL"] }
  }.freeze
  ```

  The six price ID env vars (`STRIPE_PRICE_PACK5_USD`, `STRIPE_PRICE_PACK5_BRL`, etc.) will be `nil` in test/dev environments — that is fine because `Stripe::Checkout::Session.create` is always stubbed in specs.

- [ ] **Step 2: Verify Rails boots**

  ```bash
  bin/rails runner "puts CREDIT_PACKS.keys"
  ```
  Expected: `pack_5`, `pack_15`, `pack_30`

---

## Task 6: CreditPurchase model, factory, and spec

**Files:**
- Create: `app/models/credit_purchase.rb`
- Create: `spec/factories/credit_purchases.rb`
- Create: `spec/models/credit_purchase_spec.rb`

- [ ] **Step 1: Write failing spec**

  Create `spec/models/credit_purchase_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe CreditPurchase, type: :model do
    describe "associations" do
      it { is_expected.to belong_to(:user) }
    end

    describe "validations" do
      it { is_expected.to validate_presence_of(:stripe_session_id) }
      it { is_expected.to validate_presence_of(:pack_key) }
      it { is_expected.to validate_presence_of(:credits_granted) }
      it { is_expected.to validate_presence_of(:currency) }
      it { is_expected.to validate_presence_of(:amount_cents) }
      it { is_expected.to validate_presence_of(:fulfilled_at) }
    end

    describe "database constraints" do
      it "enforces uniqueness of stripe_session_id at the DB level" do
        user = create(:user)
        create(:credit_purchase, user: user, stripe_session_id: "cs_test_123")
        expect {
          create(:credit_purchase, user: user, stripe_session_id: "cs_test_123")
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  bundle exec rspec spec/models/credit_purchase_spec.rb --format documentation
  ```
  Expected: `NameError: uninitialized constant CreditPurchase`

- [ ] **Step 3: Create the model**

  Create `app/models/credit_purchase.rb`:
  ```ruby
  class CreditPurchase < ApplicationRecord
    belongs_to :user

    validates :stripe_session_id, presence: true
    validates :pack_key, presence: true
    validates :credits_granted, presence: true
    validates :currency, presence: true
    validates :amount_cents, presence: true
    validates :fulfilled_at, presence: true
  end
  ```

- [ ] **Step 4: Create the factory**

  Create `spec/factories/credit_purchases.rb`:
  ```ruby
  FactoryBot.define do
    factory :credit_purchase do
      association :user
      sequence(:stripe_session_id) { |n| "cs_test_#{n}" }
      pack_key { "pack_5" }
      credits_granted { 5 }
      currency { "usd" }
      amount_cents { 299 }
      fulfilled_at { Time.current }
    end
  end
  ```

- [ ] **Step 5: Run tests to verify they pass**

  ```bash
  bundle exec rspec spec/models/credit_purchase_spec.rb --format documentation
  ```
  Expected: All pass.

---

## Task 7: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add routes**

  Open `config/routes.rb`. Add before the health check line:
  ```ruby
  resources :payments, only: [:new, :create] do
    collection do
      get :success
    end
  end

  post "/stripe/webhooks", to: "stripe_webhooks#create"
  ```

- [ ] **Step 2: Verify routes**

  ```bash
  bin/rails routes | grep -E "payment|webhook"
  ```
  Expected output includes: `new_payment`, `payments`, `payment_success`, `stripe_webhooks`.

---

## Task 8: PaymentsController + views

**Files:**
- Create: `app/controllers/payments_controller.rb`
- Create: `app/views/payments/new.html.erb`
- Create: `app/views/payments/success.html.erb`
- Create: `spec/requests/payments_spec.rb`

- [ ] **Step 1: Write failing request spec**

  Create `spec/requests/payments_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Payments", type: :request do
    let(:user) { create(:user) }

    describe "authentication" do
      it "redirects GET /payments/new to sign in when not authenticated" do
        get new_payment_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects POST /payments to sign in when not authenticated" do
        post payments_path, params: { pack_key: "pack_5" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "GET /payments/new" do
      before { sign_in user }

      it "returns 200" do
        get new_payment_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /payments" do
      before { sign_in user }

      let(:fake_session) do
        double("Stripe::Checkout::Session", url: "https://checkout.stripe.com/pay/cs_test_xxx")
      end

      context "with a valid pack_key and en locale" do
        it "creates a Checkout Session with the USD price and redirects to Stripe" do
          allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)

          post payments_path, params: { pack_key: "pack_5" }

          expect(Stripe::Checkout::Session).to have_received(:create).with(
            hash_including(
              line_items: [{ price: CREDIT_PACKS[:pack_5][:usd_price_id], quantity: 1 }],
              mode: "payment"
            )
          )
          expect(response).to redirect_to("https://checkout.stripe.com/pay/cs_test_xxx")
        end
      end

      context "with pt-BR locale" do
        # This works because ApplicationController#set_locale falls back to Accept-Language
        # when the user has no preferred_locale set (which is the case for the default factory).
        it "creates a Checkout Session with the BRL price" do
          allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)

          post payments_path,
            params: { pack_key: "pack_5" },
            headers: { "Accept-Language" => "pt-BR" }

          expect(Stripe::Checkout::Session).to have_received(:create).with(
            hash_including(
              line_items: [{ price: CREDIT_PACKS[:pack_5][:brl_price_id], quantity: 1 }]
            )
          )
        end
      end

      context "with an unknown pack_key" do
        it "returns 422 and does not call Stripe" do
          allow(Stripe::Checkout::Session).to receive(:create)

          post payments_path, params: { pack_key: "pack_999" }

          expect(Stripe::Checkout::Session).not_to have_received(:create)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe "GET /payments/success" do
      before { sign_in user }

      it "returns 200" do
        get payment_success_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  bundle exec rspec spec/requests/payments_spec.rb --format documentation
  ```
  Expected: Routing errors — controller does not exist yet.

- [ ] **Step 3: Implement the controller**

  Create `app/controllers/payments_controller.rb`:
  ```ruby
  class PaymentsController < ApplicationController
    before_action :authenticate_user!

    def new
    end

    def create
      pack_key = params[:pack_key].to_sym
      pack = CREDIT_PACKS[pack_key]
      return head :unprocessable_entity unless pack

      currency = CurrencyResolver.for_locale(I18n.locale)
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
    end

    def success
    end
  end
  ```

- [ ] **Step 4: Create views**

  Create `app/views/payments/new.html.erb`:
  ```erb
  <div class="max-w-2xl mx-auto px-4 py-8">
    <h1 class="text-2xl font-bold mb-6">Buy Search Credits</h1>

    <div class="grid gap-4">
      <% CREDIT_PACKS.each do |key, pack| %>
        <%= button_to payments_path(pack_key: key), method: :post, class: "block w-full text-left border rounded-lg p-4 hover:bg-gray-50" do %>
          <div class="font-semibold"><%= pack[:credits] %> searches</div>
        <% end %>
      <% end %>
    </div>
  </div>
  ```

  Create `app/views/payments/success.html.erb`:
  ```erb
  <div class="max-w-2xl mx-auto px-4 py-8 text-center">
    <h1 class="text-2xl font-bold mb-4">Payment successful</h1>
    <p class="text-gray-600 mb-6">Your search credits have been added to your account.</p>
    <%= link_to "Start searching", new_search_path, class: "btn btn-primary" %>
  </div>
  ```

- [ ] **Step 5: Run tests to verify they pass**

  ```bash
  bundle exec rspec spec/requests/payments_spec.rb --format documentation
  ```
  Expected: All pass.

---

## Task 9: StripeWebhooksController

**Files:**
- Create: `app/controllers/stripe_webhooks_controller.rb`
- Create: `spec/requests/stripe_webhooks_spec.rb`

- [ ] **Step 1: Write failing request spec**

  Create `spec/requests/stripe_webhooks_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "StripeWebhooks", type: :request do
    let(:user) { create(:user, search_credits: 0) }

    def build_event(type:, metadata: {}, session_id: "cs_test_abc", currency: "usd", amount: 299)
      Stripe::Event.construct_from({
        "type" => type,
        "data" => {
          "object" => {
            "id" => session_id,
            "object" => "checkout.session",
            "metadata" => metadata.stringify_keys,
            "currency" => currency,
            "amount_total" => amount
          }
        }
      })
    end

    def post_webhook(event)
      allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
      post "/stripe/webhooks",
        params: "{}",
        headers: {
          "Content-Type" => "application/json",
          "Stripe-Signature" => "t=1,v1=fake"
        }
    end

    describe "signature verification" do
      it "returns 400 when signature is invalid" do
        allow(Stripe::Webhook).to receive(:construct_event)
          .and_raise(Stripe::SignatureVerificationError.new("bad sig", "header"))

        post "/stripe/webhooks",
          params: "{}",
          headers: { "Content-Type" => "application/json", "Stripe-Signature" => "bad" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "unhandled event types" do
      it "returns 200 without doing anything" do
        event = build_event(type: "payment_intent.created")
        post_webhook(event)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "checkout.session.completed" do
      let(:valid_metadata) { { user_id: user.id, pack_key: "pack_5" } }

      it "grants credits and creates a CreditPurchase record" do
        event = build_event(type: "checkout.session.completed", metadata: valid_metadata)

        expect {
          post_webhook(event)
        }.to change { user.reload.search_credits }.by(5)
          .and change(CreditPurchase, :count).by(1)

        expect(response).to have_http_status(:ok)

        purchase = CreditPurchase.last
        expect(purchase.pack_key).to eq("pack_5")
        expect(purchase.credits_granted).to eq(5)
        expect(purchase.fulfilled_at).to be_present
      end

      it "returns 200 and does not double-grant on duplicate webhook" do
        event = build_event(type: "checkout.session.completed", metadata: valid_metadata, session_id: "cs_dup")
        post_webhook(event)  # first delivery

        expect {
          post_webhook(event)  # duplicate delivery
        }.not_to change { user.reload.search_credits }

        expect(response).to have_http_status(:ok)
      end

      it "returns 422 when pack_key is unknown" do
        event = build_event(
          type: "checkout.session.completed",
          metadata: { user_id: user.id, pack_key: "pack_999" }
        )
        post_webhook(event)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 200 and logs a warning when user_id is unknown" do
        event = build_event(
          type: "checkout.session.completed",
          metadata: { user_id: 999_999, pack_key: "pack_5" }
        )
        allow(Rails.logger).to receive(:warn)
        post_webhook(event)
        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:warn).with(/user not found/i)
      end
    end
  end
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  bundle exec rspec spec/requests/stripe_webhooks_spec.rb --format documentation
  ```
  Expected: Routing error — controller does not exist.

- [ ] **Step 3: Implement the controller**

  Create `app/controllers/stripe_webhooks_controller.rb`:
  ```ruby
  class StripeWebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def create
      event = verify_stripe_event
      return head :bad_request unless event
      return head :ok unless event.type == "checkout.session.completed"

      fulfill_checkout(event.data.object)
    end

    private

    def verify_stripe_event
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      Stripe::Webhook.construct_event(payload, sig_header, StripeConfig.webhook_secret)
    rescue Stripe::SignatureVerificationError
      nil
    end

    def fulfill_checkout(session)
      pack_key = session.metadata[:pack_key]
      pack = CREDIT_PACKS[pack_key&.to_sym]
      return head :unprocessable_entity unless pack

      user = User.find_by(id: session.metadata[:user_id])
      unless user
        Rails.logger.warn("StripeWebhook: user not found for session #{session.id}")
        return head :ok
      end

      ActiveRecord::Base.transaction do
        CreditPurchase.create!(
          user: user,
          stripe_session_id: session.id,
          pack_key: pack_key,
          credits_granted: pack[:credits],
          currency: session.currency.upcase,
          amount_cents: session.amount_total,
          fulfilled_at: Time.current
        )
        User.where(id: user.id).update_all(["search_credits = search_credits + ?", pack[:credits]])
      end

      head :ok
    rescue ActiveRecord::RecordNotUnique
      head :ok
    end
  end
  ```

- [ ] **Step 4: Run tests to verify they pass**

  ```bash
  bundle exec rspec spec/requests/stripe_webhooks_spec.rb --format documentation
  ```
  Expected: All pass.

---

## Task 10: Credit gate in SearchesController

**Files:**
- Modify: `app/controllers/searches_controller.rb`
- Modify: `spec/requests/searches_spec.rb`

- [ ] **Step 1: Write failing tests**

  Open `spec/requests/searches_spec.rb`. Add a new `describe` block after the existing ones:
  ```ruby
  describe "credit gate on POST /searches" do
    before { sign_in user }

    let(:valid_params) do
      {
        search_intent: {
          origin_airport: "GRU",
          destination_airport: "JFK",
          earliest_departure: 30.days.from_now.to_date.to_s,
          latest_return: 60.days.from_now.to_date.to_s,
          min_stay_days: 5,
          max_stay_days: 10,
          luggage_requirement: 0,
          max_stops: 1
        }
      }
    end

    context "when user has 0 credits" do
      before { user.update!(search_credits: 0) }

      it "redirects to new_payment_path without enqueuing a job" do
        expect(SearchRunJob).not_to receive(:perform_later)
        post searches_path, params: valid_params
        expect(response).to redirect_to(new_payment_path)
      end
    end

    context "when user has 1 or more credits" do
      before { user.update!(search_credits: 1) }

      it "enqueues a SearchRunJob" do
        expect(SearchRunJob).to receive(:perform_later)
        post searches_path, params: valid_params
      end
    end
  end
  ```

- [ ] **Step 2: Run tests to verify they fail**

  ```bash
  bundle exec rspec spec/requests/searches_spec.rb --format documentation
  ```
  Expected: The 0-credits case fails — currently it enqueues regardless.

- [ ] **Step 3: Add credit gate to SearchesController#create**

  Open `app/controllers/searches_controller.rb`. At the top of the `create` method, before any other logic, add:
  ```ruby
  def create
    if current_user.search_credits < 1
      return redirect_to new_payment_path, alert: t("payments.no_credits")
    end

    # ... rest of existing create code unchanged
  ```

- [ ] **Step 4: Add i18n key**

  Open `config/locales/en.yml`. Add under the root `en:` key:
  ```yaml
  payments:
    no_credits: "You need credits to run a search. Please purchase a pack."
  ```

  Open `config/locales/pt-BR.yml`. Add:
  ```yaml
  pt-BR:
    payments:
      no_credits: "Você precisa de créditos para realizar uma busca. Compre um pacote."
  ```

- [ ] **Step 5: Run tests to verify they pass**

  ```bash
  bundle exec rspec spec/requests/searches_spec.rb --format documentation
  ```
  Expected: All pass.

---

## Task 11: Credit deduction in SearchRunJob

**Files:**
- Modify: `app/jobs/search_run_job.rb`
- Create: `spec/jobs/search_run_job_spec.rb`

- [ ] **Step 1: Write failing spec**

  Create `spec/jobs/search_run_job_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe SearchRunJob, type: :job do
    let(:user) { create(:user, search_credits: 1) }
    let(:search_intent) { create(:search_intent, user: user) }
    let(:search_run) { create(:search_run, search_intent: search_intent) }

    before do
      # Stub repository so we don't execute a real search
      allow(Search::Repositories::SearchRunRepository).to receive(:execute)
      # Stub broadcasting — not under test here
      allow(Search::Repositories::SearchRunRepository).to receive(:load_results).and_return(nil)
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    end

    describe "credit deduction" do
      it "decrements search_credits by 1 after successful execution" do
        expect {
          described_class.new.perform(search_run.id)
        }.to change { user.reload.search_credits }.from(1).to(0)
      end

      it "does not decrement credits when execution raises" do
        allow(Search::Repositories::SearchRunRepository).to receive(:execute).and_raise(StandardError, "search failed")

        expect {
          described_class.new.perform(search_run.id) rescue nil
        }.not_to change { user.reload.search_credits }
      end

      it "does not raise when the CHECK constraint would be violated (concurrent edge case)" do
        # Force credits to 0 directly at the DB level, bypassing validations.
        # Attempting to decrement below 0 will trigger the CHECK constraint.
        user.update_columns(search_credits: 0)

        expect { described_class.new.perform(search_run.id) }.not_to raise_error
        # Credits stay at 0 — constraint prevented -1 and the job rescued gracefully.
        expect(user.reload.search_credits).to eq(0)
      end
    end
  end
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  bundle exec rspec spec/jobs/search_run_job_spec.rb --format documentation
  ```
  Expected: `decrements search_credits` fails — decrement not implemented yet.

- [ ] **Step 3: Add decrement_credit to SearchRunJob**

  Open `app/jobs/search_run_job.rb`. Place the `decrement_credit` call **between the `execute` call and the `ensure` block** — not inside `ensure`. This is critical: if `execute` raises, Ruby jumps directly to `ensure`, skipping `decrement_credit`. Credits are only deducted on the success path. Add the private method at the bottom of the class. The final file:

  ```ruby
  # frozen_string_literal: true

  class SearchRunJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(search_run_id, provider_name: Rails.application.credentials.flight_provider || "stub", max_candidates: 20, passengers: 1, cabin_class: :economy)
      provider = Flights::Registry.resolve(provider_name)
      search_run_record = SearchRun.find(search_run_id)

      Search::Repositories::SearchRunRepository.execute(
        search_run_record,
        provider: provider,
        max_candidates: max_candidates,
        passengers: passengers,
        cabin_class: cabin_class
      )

      decrement_credit(search_run_record)
    ensure
      search_run_record&.reload
      broadcast_result(search_run_record) if search_run_record
    end

    private

    def decrement_credit(search_run_record)
      User.where(id: search_run_record.search_intent.user_id)
          .update_all("search_credits = search_credits - 1")
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn("Credit decrement skipped (CHECK constraint): #{e.message}")
    end

    def broadcast_result(search_run)
      if search_run.completed?
        results = Search::Repositories::SearchRunRepository.load_results(search_run)
        presenter = SearchResultsPresenter.new(results, search_run)
        partial = presenter.low_confidence? ? "searches/low_confidence" : "searches/results"
        Turbo::StreamsChannel.broadcast_replace_to(
          "search_run_#{search_run.id}",
          target: "search_results",
          partial: partial,
          locals: { presenter: presenter }
        )
      else
        Turbo::StreamsChannel.broadcast_replace_to(
          "search_run_#{search_run.id}",
          target: "search_results",
          partial: "searches/failed",
          locals: { search_run: search_run }
        )
      end
    end
  end
  ```

- [ ] **Step 4: Run tests to verify they pass**

  ```bash
  bundle exec rspec spec/jobs/search_run_job_spec.rb --format documentation
  ```
  Expected: All pass.

- [ ] **Step 5: Run full test suite to catch regressions**

  ```bash
  bundle exec rspec
  ```
  Expected: All existing specs still pass.

---

## Final Verification

- [ ] **Run full test suite**

  ```bash
  bundle exec rspec --format progress
  ```
  Expected: All green, no failures.

- [ ] **Run security scan**

  ```bash
  bin/brakeman --no-pager
  ```
  Expected: No new warnings introduced.

- [ ] **Run linter**

  ```bash
  bin/rubocop
  ```
  Fix any offenses with `bin/rubocop -a`.

---

## Environment Variables Required for Production

Before deploying, set these in your environment:

| Variable | Description |
|---|---|
| `STRIPE_SECRET_KEY` | Stripe live secret key (`sk_live_...`) |
| `STRIPE_WEBHOOK_SECRET` | From Stripe Dashboard → Webhooks (`whsec_...`) |
| `STRIPE_PRICE_PACK5_USD` | Stripe Price ID for 5-credit pack in USD |
| `STRIPE_PRICE_PACK5_BRL` | Stripe Price ID for 5-credit pack in BRL |
| `STRIPE_PRICE_PACK15_USD` | Stripe Price ID for 15-credit pack in USD |
| `STRIPE_PRICE_PACK15_BRL` | Stripe Price ID for 15-credit pack in BRL |
| `STRIPE_PRICE_PACK30_USD` | Stripe Price ID for 30-credit pack in USD |
| `STRIPE_PRICE_PACK30_BRL` | Stripe Price ID for 30-credit pack in BRL |

In Stripe Dashboard: create three Products with two Prices each (USD + BRL). Enable dynamic payment methods. Enable PIX for BRL. Register the webhook endpoint pointing to `https://your-domain.com/stripe/webhooks` listening for `checkout.session.completed`.
