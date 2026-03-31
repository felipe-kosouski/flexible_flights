# Welcome Email Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send a branded welcome email after a user confirms their email address, using a warm onboarding tone with a search tip and a direct CTA.

**Architecture:** A new `UserMailer` sends the welcome email via `deliver_later` (Solid Queue). A custom `Users::ConfirmationsController` hooks into Devise's `after_confirmation_path_for` — called only on successful confirmation — to enqueue the email. This keeps the side effect in the controller layer, not the model.

**Tech Stack:** Rails 8, ActionMailer, Devise `:confirmable`, Solid Queue (`deliver_later`), RSpec (`have_enqueued_mail`).

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `app/mailers/application_mailer.rb` | Create | Base mailer with `from` default and `layout false` |
| `app/mailers/user_mailer.rb` | Create | `welcome(user)` action |
| `app/views/user_mailer/welcome.html.erb` | Create | Inline-styled HTML welcome email |
| `app/controllers/users/confirmations_controller.rb` | Create | Override `after_confirmation_path_for` to enqueue welcome email |
| `config/routes.rb` | Modify | Add `confirmations: "users/confirmations"` to `devise_for` |
| `spec/mailers/user_mailer_spec.rb` | Create | Mailer unit spec |
| `spec/requests/confirmations_spec.rb` | Modify | Add 2 examples for welcome email enqueuing |

---

### Task 1: ApplicationMailer + UserMailer + routes

**Files:**
- Create: `app/mailers/application_mailer.rb`
- Create: `app/mailers/user_mailer.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing mailer unit spec**

Create `spec/mailers/user_mailer_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#welcome" do
    let(:user) { create(:user) }
    subject(:mail) { described_class.welcome(user) }

    it "sends to the user's email" do
      expect(mail.to).to eq([user.email])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("You're confirmed — here's your free search")
    end

    it "includes the search CTA URL" do
      expect(mail.body.encoded).to include(new_search_url(host: "www.example.com"))
    end

    it "includes the welcome heading" do
      expect(mail.body.encoded).to include("You&#39;re all set")
    end

    it "includes the date window tip" do
      expect(mail.body.encoded).to include("flexible date window")
    end
  end
end
```

- [ ] **Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/mailers/user_mailer_spec.rb
```

Expected: `NameError: uninitialized constant UserMailer`

- [ ] **Step 3: Create ApplicationMailer**

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "hello@flexibleflights.com"
  layout false
end
```

- [ ] **Step 4: Create UserMailer**

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: @user.email, subject: "You're confirmed — here's your free search")
  end
end
```

- [ ] **Step 5: Create the email template**

```erb
<%# app/views/user_mailer/welcome.html.erb %>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>You're confirmed — Flexible Flights</title>
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

              <p style="margin:0 0 6px;font-size:18px;font-weight:600;color:#1c1814;line-height:1.3;">You're all set.</p>
              <p style="margin:0 0 24px;font-size:14px;color:#6e6760;line-height:1.6;">Your account is confirmed and your free search is ready to use. Here's how to get the most out of it.</p>

              <%# ── Tip box ── %>
              <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:24px;">
                <tr>
                  <td style="background-color:#e8f4f8;border-radius:8px;padding:16px 18px;">
                    <p style="margin:0 0 6px;font-size:11px;font-weight:600;color:#0D4A62;text-transform:uppercase;letter-spacing:0.06em;">Quick tip</p>
                    <p style="margin:0;font-size:13px;color:#1c1814;line-height:1.6;">Use a <strong>flexible date window</strong> — at least 2–3 weeks. The wider the range, the more price patterns Flexible Flights can analyse, and the sharper the recommendation you'll get.</p>
                  </td>
                </tr>
              </table>

              <%# ── CTA button ── %>
              <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:24px;">
                <tr>
                  <td align="center">
                    <%= link_to "Use my free search \u2192",
                          new_search_url,
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

              <%# ── What happens next ── %>
              <p style="margin:0 0 10px;font-size:11px;font-weight:600;color:#9e9590;text-transform:uppercase;letter-spacing:0.06em;">What happens next</p>

              <table cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:8px;">
                <tr>
                  <td style="color:#E8784C;font-size:14px;padding-right:8px;vertical-align:top;padding-top:2px;">&#8594;</td>
                  <td style="font-size:13px;color:#6e6760;line-height:1.5;">We sample prices across your travel window and build a market picture</td>
                </tr>
              </table>

              <table cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:8px;">
                <tr>
                  <td style="color:#E8784C;font-size:14px;padding-right:8px;vertical-align:top;padding-top:2px;">&#8594;</td>
                  <td style="font-size:13px;color:#6e6760;line-height:1.5;">Each flight gets a score, an explanation, and a book-now-or-wait call</td>
                </tr>
              </table>

              <table cellpadding="0" cellspacing="0" role="presentation" style="margin-bottom:24px;">
                <tr>
                  <td style="color:#E8784C;font-size:14px;padding-right:8px;vertical-align:top;padding-top:2px;">&#8594;</td>
                  <td style="font-size:13px;color:#6e6760;line-height:1.5;">The best options float to the top — ranked by value, not just price</td>
                </tr>
              </table>

              <%# ── Footer ── %>
              <p style="margin:0;font-size:12px;color:#9e9590;text-align:center;line-height:1.5;">Questions? Reply to this email — we read every one.</p>

            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>
```

- [ ] **Step 6: Run mailer spec to verify it passes**

```bash
bundle exec rspec spec/mailers/user_mailer_spec.rb
```

Expected: 5 examples, 0 failures.

Note: the "includes the search CTA URL" example uses `new_search_url(host: "www.example.com")` — this matches the `default_url_options` set in `config/environments/test.rb`.

- [ ] **Step 7: Update routes.rb**

```ruby
Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    confirmations: "users/confirmations"
  }
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

- [ ] **Step 8: Commit**

```bash
git add app/mailers/application_mailer.rb app/mailers/user_mailer.rb app/views/user_mailer/welcome.html.erb config/routes.rb spec/mailers/user_mailer_spec.rb
git commit -m "feat: add UserMailer with welcome email"
```

---

### Task 2: Custom confirmations controller + request specs

**Files:**
- Create: `app/controllers/users/confirmations_controller.rb`
- Modify: `spec/requests/confirmations_spec.rb`

- [ ] **Step 1: Add failing request spec examples**

Append to `spec/requests/confirmations_spec.rb` (inside the existing `RSpec.describe` block, after the last `describe` block):

```ruby
  describe "welcome email on confirmation" do
    it "enqueues a welcome email when a valid token is confirmed" do
      user = create(:user, confirmed_at: nil, confirmation_token: "validtoken123", confirmation_sent_at: 1.hour.ago)
      expect {
        get user_confirmation_path, params: { confirmation_token: "validtoken123" }
      }.to have_enqueued_mail(UserMailer, :welcome).with(user)
    end

    it "does not enqueue a welcome email for an invalid token" do
      expect {
        get user_confirmation_path, params: { confirmation_token: "badtoken" }
      }.not_to have_enqueued_mail(UserMailer, :welcome)
    end
  end
```

- [ ] **Step 2: Run the new specs to confirm they fail**

```bash
bundle exec rspec spec/requests/confirmations_spec.rb -e "welcome email"
```

Expected: 2 failures — `have_enqueued_mail` fails because no welcome email is sent yet.

- [ ] **Step 3: Create the custom confirmations controller**

```ruby
# app/controllers/users/confirmations_controller.rb
class Users::ConfirmationsController < Devise::ConfirmationsController
  protected

  # Called by Devise only when confirmation succeeds (valid token, not yet confirmed).
  # Side effect (welcome email) lives here, not in the model — consistent with architecture.
  def after_confirmation_path_for(resource_name, resource)
    UserMailer.welcome(resource).deliver_later
    super
  end
end
```

- [ ] **Step 4: Run the confirmation request specs**

```bash
bundle exec rspec spec/requests/confirmations_spec.rb
```

Expected: all 9 examples pass.

- [ ] **Step 5: Run the full suite**

```bash
bundle exec rspec
```

Expected: 9 pre-existing failures (Amadeus/Stripe credentials), nothing new.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/users/confirmations_controller.rb spec/requests/confirmations_spec.rb
git commit -m "feat: send welcome email after email confirmation"
```

---

## Done

Full welcome email flow live:

1. User confirms email → `after_confirmation_path_for` fires
2. `UserMailer.welcome(user).deliver_later` enqueues the job via Solid Queue
3. User receives branded welcome email with tip + CTA → clicks through to their free search
