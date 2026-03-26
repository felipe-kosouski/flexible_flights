# Email Confirmation — Design Spec

## Overview

Enable Devise's `:confirmable` module to require users to verify their email before accessing the app. Users are blocked immediately (no grace period). The confirmation email doubles as a first onboarding touchpoint.

---

## Scope

- Enable Devise `:confirmable` on `User`
- Block access until email is confirmed (`allow_unconfirmed_access_for = 0.days`)
- Branded confirmation email (warm tone, value prop, inline styles for email client compatibility)
- Dedicated "Check your email" page shown after sign-up
- Styled resend confirmation view
- Auto-confirm existing users in migration so they are not locked out
- Update `.gitignore` to exclude `.superpowers/`

---

## 1. Migration

Add standard Devise confirmable columns to `users`:

```ruby
add_column :users, :confirmation_token, :string
add_column :users, :confirmed_at, :datetime
add_column :users, :confirmation_sent_at, :datetime
add_column :users, :unconfirmed_email, :string  # required by reconfirmable

add_index :users, :confirmation_token, unique: true
```

**Auto-confirm existing users** in the same migration:

```ruby
User.update_all(confirmed_at: Time.current)
```

This prevents existing accounts from being locked out when the feature goes live.

---

## 2. User Model

Add `:confirmable` to the Devise modules list:

```ruby
devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable,
       :confirmable
```

No other model changes required.

---

## 3. Devise Configuration (`config/initializers/devise.rb`)

Two changes:

```ruby
config.mailer_sender = "hello@flexibleflights.com"
config.allow_unconfirmed_access_for = 0.days
```

`reconfirmable = true` is already set — email changes will also require re-confirmation.

---

## 4. Custom Registrations Controller

Override `after_inactive_sign_up_path_for` to redirect to the new check-email page, passing the user's email via flash so the page can display it:

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

Update `routes.rb` to use this controller:

```ruby
devise_for :users, controllers: { registrations: "users/registrations" }
```

---

## 5. "Check Your Email" Page

**Route:** `GET /check-email` → `pages#check_email`

**View behavior:**
- Reads `flash[:unconfirmed_email]` to display the user's email address
- Shows a spam-folder tip
- Links to `/users/confirmation/new` (resend confirmation)
- If flash is missing (direct navigation), omits the email address gracefully

**Visual design:** White card (`rounded-2xl border border-gray-200 px-8 py-10`) matching the auth pages. Teal envelope icon in a brand-light chip. Accent-colored resend link.

---

## 6. Confirmation Email Template

**File:** `app/views/devise/mailer/confirmation_instructions.html.erb`

Full inline-styled HTML email (for email client compatibility — no Tailwind, no external CSS). Design tokens used as literal hex values.

**Structure:**
- **Header:** Dark teal (`#0D4A62`) background, SVG logo mark, "Flexible Flights" wordmark in white
- **Body (white card):**
  - Heading: "Welcome aboard." (`#1c1814`, 18px, 600)
  - Copy: "You're one step away from finding out when to fly — and whether to book now or wait. Confirm your email to get started with your free search."
  - CTA button: accent orange (`#E8784C`), full-width, "Confirm my account"
  - Divider
  - "What you get" section (label style, uppercase, small):
    - → 1 free search to explore pricing across your travel window
    - → Score, explanation, and a book-now-or-wait recommendation for every flight
  - Footer note: "If you didn't create this account, you can ignore this email." (muted, centered, 12px)
- **Outer background:** `#fafaf8`

**Fonts:** Email clients ignore Google Fonts. Use `font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif` throughout.

---

## 7. Resend Confirmation View

**File:** `app/views/devise/confirmations/new.html.erb`

Restyled to match the auth card pattern:
- Same card shell as sign-in / sign-up (`rounded-2xl border border-gray-200 px-8 py-10`)
- Heading: "Resend confirmation"
- Subtext: "Enter your email and we'll send a new confirmation link."
- Email field: standard form input pattern from design system
- Submit button: accent primary (`bg-accent-500 hover:bg-accent-600`, `h-11`)
- Footer link: "Back to sign in" → `new_user_session_path`

---

## 8. `.gitignore`

Add `.superpowers/` to prevent brainstorm session files from being committed.

---

## Files Changed

| File | Change |
|------|--------|
| `db/migrate/TIMESTAMP_add_confirmable_to_users.rb` | New migration |
| `app/models/user.rb` | Add `:confirmable` |
| `config/initializers/devise.rb` | `mailer_sender`, `allow_unconfirmed_access_for` |
| `app/controllers/users/registrations_controller.rb` | New — override redirect |
| `config/routes.rb` | Use custom registrations controller, add `check_email` route |
| `app/controllers/pages_controller.rb` | Add `check_email` action |
| `app/views/pages/check_email.html.erb` | New view |
| `app/views/devise/mailer/confirmation_instructions.html.erb` | Replace with branded template |
| `app/views/devise/confirmations/new.html.erb` | Restyle to match auth pages |
| `.gitignore` | Add `.superpowers/` |

---

## Out of Scope

- Plain-text version of confirmation email (Devise sends HTML only by default)
- i18n for new views (can be added in a follow-up)
- Admin tooling to manually confirm users
