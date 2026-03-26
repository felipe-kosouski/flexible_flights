# Email Confirmation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Devise `:confirmable` to block unconfirmed users, send a branded confirmation email, and show a dedicated "Check your email" page after sign-up.

**Architecture:** Add `:confirmable` to the `User` model with zero grace period. A custom `Users::RegistrationsController` overrides the post-sign-up redirect to a new `PagesController#check_email` action that displays the user's email and a resend link. The confirmation email is a fully inline-styled HTML email matching the Flexible Flights design system.

**Tech Stack:** Ruby on Rails 8, Devise `:confirmable`, ERB, inline CSS (email), Tailwind CSS (web views), RSpec request specs.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `.gitignore` | Modify | Add `.superpowers/` |
| `db/migrate/20260326120000_add_confirmable_to_users.rb` | Create | Add confirmation columns + auto-confirm existing users |
| `app/models/user.rb` | Modify | Add `:confirmable` to Devise modules |
| `config/initializers/devise.rb` | Modify | Set `mailer_sender` and `allow_unconfirmed_access_for` |
| `spec/factories/users.rb` | Modify | Add `confirmed_at` so existing tests keep passing |
| `app/controllers/users/registrations_controller.rb` | Create | Override post-sign-up redirect |
| `config/routes.rb` | Modify | Use custom registrations controller + add `check_email` route |
| `app/controllers/pages_controller.rb` | Modify | Add `check_email` action |
| `app/views/pages/check_email.html.erb` | Create | "Check your email" page |
| `app/views/devise/mailer/confirmation_instructions.html.erb` | Modify | Branded inline-styled confirmation email |
| `app/views/devise/confirmations/new.html.erb` | Modify | Restyled resend confirmation form |
| `spec/requests/confirmations_spec.rb` | Create | Request specs for the full confirmation flow |

---

### Task 1: Update .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Add `.superpowers/` to .gitignore**

Open `.gitignore` and add after the `/tmp` block:

```
/.superpowers/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore .superpowers brainstorm directory"
```

---

### Task 2: Migration — add confirmable columns

**Files:**
- Create: `db/migrate/20260326120000_add_confirmable_to_users.rb`

- [ ] **Step 1: Create the migration file**

```ruby
# db/migrate/20260326120000_add_confirmable_to_users.rb
class AddConfirmableToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    add_index :users, :confirmation_token, unique: true

    # Auto-confirm all existing users so they are not locked out
    reversible do |dir|
      dir.up { User.update_all(confirmed_at: Time.current) }
    end
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
bin/rails db:migrate
```

Expected output ends with:
```
== 20260326120000 AddConfirmableToUsers: migrated
```

- [ ] **Step 3: Commit**

```bash
git add db/migrate/20260326120000_add_confirmable_to_users.rb db/schema.rb
git commit -m "feat: add Devise confirmable columns to users"
```

---

### Task 3: Enable `:confirmable` in model + Devise config + update factory

**Files:**
- Modify: `app/models/user.rb`
- Modify: `config/initializers/devise.rb`
- Modify: `spec/factories/users.rb`

- [ ] **Step 1: Add `:confirmable` to User model**

In `app/models/user.rb`, change the devise line from:

```ruby
devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable
```

to:

```ruby
devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable,
       :confirmable
```

- [ ] **Step 2: Update Devise config — mailer sender**

In `config/initializers/devise.rb`, change line 27:

```ruby
config.mailer_sender = "please-change-me-at-config-initializers-devise@example.com"
```

to:

```ruby
config.mailer_sender = "hello@flexibleflights.com"
```

- [ ] **Step 3: Update Devise config — block unconfirmed access**

In `config/initializers/devise.rb`, uncomment and set line 146:

```ruby
config.allow_unconfirmed_access_for = 0.days
```

- [ ] **Step 4: Update user factory to pre-confirm users**

Existing request specs use `sign_in user` (Devise test helper — bypasses confirmation). However, updating the factory prevents subtle failures in any spec that exercises the actual sign-in form. Replace `spec/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    first_name { "Jane" }
    last_name { "Doe" }
    confirmed_at { Time.current }
  end
end
```

- [ ] **Step 5: Run full test suite to verify nothing regressed**

```bash
bundle exec rspec
```

Expected: all existing specs pass. Any failure here is a regression introduced by this task — fix before continuing.

- [ ] **Step 6: Commit**

```bash
git add app/models/user.rb config/initializers/devise.rb spec/factories/users.rb
git commit -m "feat: enable Devise confirmable with zero grace period"
```

---

### Task 4: Custom registrations controller + updated routes

**Files:**
- Create: `app/controllers/users/registrations_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/confirmations_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Email confirmation flow", type: :request do
  describe "POST /users (sign up)" do
    it "redirects to check-email page after sign-up" do
      post user_registration_path, params: {
        user: {
          email: "new@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
      expect(response).to redirect_to(check_email_path)
    end

    it "stores the email in flash for the check-email page" do
      post user_registration_path, params: {
        user: {
          email: "new@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
      follow_redirect!
      expect(response.body).to include("new@example.com")
    end
  end

  describe "GET /check-email" do
    it "returns 200" do
      get check_email_path
      expect(response).to have_http_status(:ok)
    end

    it "includes a link to resend confirmation" do
      get check_email_path
      expect(response.body).to include(new_user_confirmation_path)
    end
  end

  describe "GET /users/confirmation/new" do
    it "returns 200" do
      get new_user_confirmation_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "confirmed user sign-in" do
    it "signs in a confirmed user successfully" do
      user = create(:user) # confirmed_at set by factory
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      expect(response).to redirect_to(new_search_path)
    end
  end

  describe "unconfirmed user sign-in" do
    it "blocks sign-in and shows an error" do
      user = create(:user, confirmed_at: nil)
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      expect(response).not_to redirect_to(new_search_path)
    end
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
bundle exec rspec spec/requests/confirmations_spec.rb
```

Expected: multiple failures — `check_email_path` undefined, redirect goes to wrong path.

- [ ] **Step 3: Create the custom registrations controller**

```ruby
# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  private

  def after_inactive_sign_up_path_for(resource)
    flash[:unconfirmed_email] = resource.email
    check_email_path
  end
end
```

- [ ] **Step 4: Update routes.rb**

```ruby
Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }
  root "pages#home"

  get "check-email", to: "pages#check_email", as: :check_email

  resources :searches, only: [ :new, :create, :show ]

  get "history", to: "search_history#index", as: :search_history

  resource :profile, only: [ :show, :update, :destroy ], controller: "profile"

  resources :payments, only: [ :new, :create ] do
    collection do
      get :success
    end
  end

  post "/stripe/webhooks", to: "stripe_webhooks#create"

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 5: Run specs — expect routing to resolve but view missing**

```bash
bundle exec rspec spec/requests/confirmations_spec.rb
```

Expected: failures change to `ActionController::UnknownAction` or missing template — routing is now wired.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/users/registrations_controller.rb config/routes.rb
git commit -m "feat: redirect post-sign-up to check-email page"
```

---

### Task 5: Check-email page

**Files:**
- Modify: `app/controllers/pages_controller.rb`
- Create: `app/views/pages/check_email.html.erb`

- [ ] **Step 1: Add `check_email` action to PagesController**

```ruby
class PagesController < ApplicationController
  def home
    redirect_to new_search_path if user_signed_in?
  end

  def check_email
  end
end
```

- [ ] **Step 2: Create the check-email view**

```erb
<%# app/views/pages/check_email.html.erb %>
<% content_for :title, "Check your email — Flexible Flights" %>

<div class="w-full max-w-md">
  <div class="bg-white rounded-2xl border border-gray-200 px-8 py-10">

    <div class="w-12 h-12 rounded-xl bg-brand-50 flex items-center justify-center mb-5">
      <svg class="w-6 h-6 text-brand-600" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" aria-hidden="true">
        <rect x="2" y="4" width="20" height="16" rx="2" stroke="currentColor"/>
        <path d="m2 7 10 7 10-7"/>
      </svg>
    </div>

    <h1 class="text-xl font-semibold text-gray-900 mb-2">Check your email</h1>

    <p class="text-sm text-gray-500 leading-relaxed mb-5">
      We sent a confirmation link to
      <% if flash[:unconfirmed_email].present? %>
        <strong class="text-gray-800"><%= flash[:unconfirmed_email] %></strong>.
      <% else %>
        your email address.
      <% end %>
      Click it to activate your account and use your free search.
    </p>

    <div class="bg-gray-50 border border-gray-200 rounded-lg px-4 py-3 mb-5">
      <p class="text-xs text-gray-500 leading-relaxed">
        <strong class="text-gray-700">Didn't get it?</strong>
        Check your spam folder. It usually arrives within a minute.
      </p>
    </div>

    <p class="text-sm text-gray-500 text-center">
      Still nothing?
      <%= link_to "Resend confirmation email", new_user_confirmation_path,
            class: "text-brand-700 hover:text-brand-800 font-medium" %>
    </p>

  </div>
</div>
```

- [ ] **Step 3: Run the confirmation spec**

```bash
bundle exec rspec spec/requests/confirmations_spec.rb
```

Expected: all specs pass.

- [ ] **Step 4: Run full suite to verify no regressions**

```bash
bundle exec rspec
```

Expected: all specs pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/pages_controller.rb app/views/pages/check_email.html.erb spec/requests/confirmations_spec.rb
git commit -m "feat: add check-email page shown after sign-up"
```

---

### Task 6: Style resend confirmation view

**Files:**
- Modify: `app/views/devise/confirmations/new.html.erb`

- [ ] **Step 1: Replace the unstyled view**

```erb
<%# app/views/devise/confirmations/new.html.erb %>
<% content_for :title, "Resend confirmation — Flexible Flights" %>

<div class="w-full max-w-md">
  <div class="bg-white rounded-2xl border border-gray-200 px-8 py-10">
    <h1 class="text-xl font-semibold text-gray-900 tracking-tight mb-2">Resend confirmation</h1>
    <p class="text-sm text-gray-500 mb-6">Enter your email and we'll send a new confirmation link.</p>

    <%= form_for(resource, as: resource_name, url: confirmation_path(resource_name), html: { method: :post }) do |f| %>
      <%= render "devise/shared/error_messages", resource: resource %>

      <div class="space-y-5">
        <div>
          <%= f.label :email, class: "block text-sm font-medium text-gray-700 mb-1.5" %>
          <%= f.email_field :email,
                autofocus: true,
                autocomplete: "email",
                value: (resource.pending_reconfirmation? ? resource.unconfirmed_email : resource.email),
                class: "w-full rounded-lg border border-gray-300 px-3.5 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600" %>
        </div>

        <%= f.submit "Send confirmation email",
              class: "w-full bg-accent-500 hover:bg-accent-600 text-white text-sm font-semibold rounded-lg px-5 h-11 transition-colors cursor-pointer" %>
      </div>
    <% end %>

    <p class="mt-6 text-center text-sm text-gray-500">
      <%= link_to "Back to sign in", new_user_session_path, class: "text-brand-700 hover:text-brand-800 font-medium" %>
    </p>
  </div>
</div>
```

- [ ] **Step 2: Run the confirmation spec**

```bash
bundle exec rspec spec/requests/confirmations_spec.rb
```

Expected: all pass (the `GET /users/confirmation/new` spec should still pass).

- [ ] **Step 3: Commit**

```bash
git add app/views/devise/confirmations/new.html.erb
git commit -m "feat: restyle resend confirmation view to match auth pages"
```

---

### Task 7: Branded confirmation email template

**Files:**
- Modify: `app/views/devise/mailer/confirmation_instructions.html.erb`

- [ ] **Step 1: Replace with inline-styled branded template**

Email clients ignore external stylesheets. All styles must be inline. Replace the file entirely:

```erb
<%# app/views/devise/mailer/confirmation_instructions.html.erb %>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Confirm your Flexible Flights account</title>
</head>
<body style="margin:0;padding:0;background-color:#fafaf8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background-color:#fafaf8;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width:520px;" cellpadding="0" cellspacing="0" role="presentation">

          <%# ── Header ── %>
          <tr>
            <td style="background-color:#0D4A62;border-radius:12px 12px 0 0;padding:18px 28px;">
              <table cellpadding="0" cellspacing="0" role="presentation">
                <tr>
                  <td style="vertical-align:middle;padding-right:10px;">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <line x1="2" y1="18" x2="22" y2="18" stroke="#4B9AB8" stroke-width="2" stroke-linecap="round"/>
                      <line x1="6" y1="18" x2="18" y2="6" stroke="#4B9AB8" stroke-width="2" stroke-linecap="round"/>
                      <circle cx="18" cy="6" r="3" fill="#E8784C"/>
                    </svg>
                  </td>
                  <td style="vertical-align:middle;">
                    <span style="color:#ffffff;font-size:15px;font-weight:600;letter-spacing:-0.01em;">Flexible Flights</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <%# ── Body ── %>
          <tr>
            <td style="background-color:#ffffff;border:1px solid #e4dfd8;border-top:none;border-radius:0 0 12px 12px;padding:28px;">

              <p style="margin:0 0 6px;font-size:18px;font-weight:600;color:#1c1814;line-height:1.3;">Welcome aboard.</p>
              <p style="margin:0 0 24px;font-size:14px;color:#6e6760;line-height:1.6;">You're one step away from finding out when to fly — and whether to book now or wait. Confirm your email to get started with your free search.</p>

              <%# ── CTA button ── %>
              <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:24px;">
                <tr>
                  <td align="center">
                    <%= link_to "Confirm my account",
                          confirmation_url(@resource, confirmation_token: @token),
                          style: "display:inline-block;background-color:#E8784C;color:#ffffff;text-decoration:none;font-size:14px;font-weight:600;padding:12px 32px;border-radius:8px;text-align:center;" %>
                  </td>
                </tr>
              </table>

              <%# ── Divider ── %>
              <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:20px;">
                <tr>
                  <td style="border-top:1px solid #e4dfd8;font-size:0;line-height:0;">&nbsp;</td>
                </tr>
              </table>

              <%# ── What you get ── %>
              <p style="margin:0 0 10px;font-size:11px;font-weight:600;color:#9e9590;text-transform:uppercase;letter-spacing:0.06em;">What you get</p>

              <table cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:8px;">
                <tr>
                  <td style="color:#E8784C;font-size:14px;padding-right:8px;vertical-align:top;padding-top:2px;">&#8594;</td>
                  <td style="font-size:13px;color:#6e6760;line-height:1.5;">1 free search to explore pricing across your travel window</td>
                </tr>
              </table>

              <table cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:24px;">
                <tr>
                  <td style="color:#E8784C;font-size:14px;padding-right:8px;vertical-align:top;padding-top:2px;">&#8594;</td>
                  <td style="font-size:13px;color:#6e6760;line-height:1.5;">Score, explanation, and a book-now-or-wait recommendation for every flight</td>
                </tr>
              </table>

              <%# ── Footer note ── %>
              <p style="margin:0;font-size:12px;color:#9e9590;text-align:center;line-height:1.5;">If you didn't create this account, you can ignore this email.</p>

            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>
```

- [ ] **Step 2: Run full suite one final time**

```bash
bundle exec rspec
```

Expected: all specs pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/devise/mailer/confirmation_instructions.html.erb
git commit -m "feat: branded confirmation email with onboarding copy"
```

---

## Done

All seven tasks complete. The full confirmation flow is live:

1. User signs up → email sent → redirected to `/check-email`
2. Unconfirmed user who tries to sign in → blocked by Devise with a flash error
3. User clicks confirmation link → confirmed → can sign in and run their free search
4. User can resend from `/users/confirmation/new` or via the link on `/check-email`
