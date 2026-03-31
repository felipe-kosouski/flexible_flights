# Welcome Email — Design Spec

## Overview

Send a branded welcome email after a user confirms their email address. The email serves as a warm onboarding touchpoint — distinct from the confirmation email — with a concrete search tip and a direct CTA to use the free credit.

---

## Scope

- New `UserMailer` with a `welcome(user)` action
- Inline-styled HTML email template matching the Flexible Flights design system
- Custom `Users::ConfirmationsController` that hooks into Devise's successful confirmation to send the email
- Update routes to use the custom confirmations controller
- `deliver_later` via Solid Queue (existing job backend)

---

## Trigger

The welcome email fires from `after_confirmation_path_for` in the custom confirmations controller. Devise calls this method **only when confirmation succeeds** (valid token, not already confirmed), passing the confirmed resource. This is the correct hook — no need to check error state or override `show`.

This keeps the side effect in the controller layer, consistent with the project rule that AR models are validation + associations only.

---

## 1. ApplicationMailer

No `ApplicationMailer` exists yet. Create the base class before `UserMailer`:

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "hello@flexibleflights.com"
  layout false
end
```

`layout false` — email templates are self-contained HTML documents, not wrapped in a layout.

---

## 2. UserMailer

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: @user.email, subject: "You're confirmed — here's your free search")
  end
end
```

The `@user` instance variable is available in the template.

---

## 3. Email Template

**File:** `app/views/user_mailer/welcome.html.erb`

Full inline-styled HTML email. No Tailwind, no external CSS — every style is a `style=""` attribute.

**Structure:**
- **Outer background:** `#fafaf8`
- **Header:** `#0D4A62` teal background, SVG logo mark (horizon line `#4B9AB8`, circle `#E8784C`), "Flexible Flights" wordmark in white
- **Body card:** white (`#ffffff`), border `#e4dfd8`, `border-radius: 0 0 12px 12px`
  - **Heading:** "You're all set." — 18px, 600, `#1c1814`
  - **Intro:** "Your account is confirmed and your free search is ready to use. Here's how to get the most out of it."
  - **Tip box:** brand-light background `#e8f4f8`, label "QUICK TIP" in `#0D4A62` uppercase, copy: "Use a **flexible date window** — at least 2–3 weeks. The wider the range, the more price patterns Flexible Flights can analyse, and the sharper the recommendation you'll get."
  - **CTA button:** "Use my free search →", background `#E8784C`, white text, links to `new_search_url`
  - **Divider**
  - **"What happens next"** label (uppercase, 11px, `#9e9590`) + 3 bullets with `&#8594;` arrows in `#E8784C`:
    - We sample prices across your travel window and build a market picture
    - Each flight gets a score, an explanation, and a book-now-or-wait call
    - The best options float to the top — ranked by value, not just price
  - **Footer:** "Questions? Reply to this email — we read every one." — 12px, `#9e9590`, centered

**Font stack:** `-apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif` (Google Fonts not available in email clients)

---

## 4. Custom Confirmations Controller

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

`super` returns Devise's default `after_confirmation_path_for` — typically `new_session_path` or `root_path`, which is correct.

---

## 5. Routes

Add `confirmations: "users/confirmations"` to the existing `devise_for` line:

```ruby
devise_for :users, controllers: {
  registrations: "users/registrations",
  confirmations: "users/confirmations"
}
```

---

## Testing

**Mailer unit spec** (`spec/mailers/user_mailer_spec.rb`):
- Subject is `"You're confirmed — here's your free search"`
- Recipient is the user's email
- Body includes `new_search_url`
- Body includes "You're all set"
- Body includes "flexible date window"

**Request spec** (add to `spec/requests/confirmations_spec.rb`):
- `GET /users/confirmation?confirmation_token=<token>` with a valid unconfirmed user enqueues `UserMailer#welcome`
- Already-confirmed user hitting the link does NOT enqueue a second welcome email

**Test adapter:** `deliver_later` in tests uses `ActiveJob::TestAdapter` — use `have_enqueued_mail(UserMailer, :welcome)` matcher.

---

## Files Changed

| File | Action |
|------|--------|
| `app/mailers/application_mailer.rb` | Create |
| `app/mailers/user_mailer.rb` | Create |
| `app/views/user_mailer/welcome.html.erb` | Create |
| `app/controllers/users/confirmations_controller.rb` | Create |
| `config/routes.rb` | Add `confirmations:` to `devise_for` |
| `spec/mailers/user_mailer_spec.rb` | Create |
| `spec/requests/confirmations_spec.rb` | Extend with 2 new examples |

---

## Out of Scope

- Plain-text fallback email
- i18n / locale-aware copy
- Welcome email for users created via admin or seeding
- Re-sending the welcome email on re-confirmation (email change)
