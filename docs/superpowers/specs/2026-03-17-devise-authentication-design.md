# Devise Authentication — Design Spec

**Date:** 2026-03-17
**Status:** Approved
**Scope:** MVP authentication flow — register, sign in, sign out, password reset

---

## Context

The app currently uses a guest user pattern: `ApplicationController` creates a random `guest_*@guest.local` user on first visit and stores the ID in the session. The `users` table has only `email` (unique, not null) and timestamps. No auth gem is installed.

This design replaces the guest pattern with full Devise authentication.

---

## Decision

Use Devise with a minimal set of modules. Devise is the industry-standard Rails auth gem with a large ecosystem — chosen over Rails 8 built-in auth because future SaaS needs (OAuth, invitations, email confirmation) are better served by Devise's modular extension points.

---

## Modules

```ruby
devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
```

| Module | Purpose |
|--------|---------|
| `database_authenticatable` | BCrypt password hashing, session-based sign-in |
| `registerable` | Sign-up flow |
| `recoverable` | Password reset via email |
| `rememberable` | "Remember me" cookie |
| `validatable` | Email format + password length validations |

Excluded (not needed for MVP): `confirmable`, `lockable`, `trackable`, `timeoutable`, `omniauthable`.

---

## Database

The existing `users` table is extended — not replaced. A migration adds Devise columns on top of the existing `email` column (which already has a unique index):

- `encrypted_password` (string, not null, default "")
- `reset_password_token` (string, unique index)
- `reset_password_sent_at` (datetime)
- `remember_created_at` (datetime)

No data loss. Existing user records (including any guest rows) remain. Guest user rows (`guest_*@guest.local`) will receive an empty string as `encrypted_password` — they are harmless orphaned records. A cleanup of guest rows is out of scope for MVP but should be done before any production launch.

---

## Access Control

- `ApplicationController`: remove the `current_user` / `create_guest_user` guest pattern. Devise provides `current_user` automatically.
- `SearchesController`: add `before_action :authenticate_user!` with no `only:` restriction — all three actions (`new`, `create`, `show`) require authentication. Unauthenticated requests are redirected to sign in.
- After sign-in, Devise redirects the user back to their originally requested URL.
- Root path (`/`) remains `searches#new`, which requires authentication.

### IDOR fix

`searches#show` currently fetches any `SearchRun` by ID with no user scoping, which is an Insecure Direct Object Reference. With authentication in place, the fetch must be scoped to the current user:

```ruby
@search_run = current_user.search_intents
                           .joins(:search_runs)
                           .merge(SearchRun.where(id: params[:id]))
                           .includes(search_intent: :user)
                           .first!
```

Or equivalently via a `has_many :through` if one exists. The important constraint: a user cannot view another user's search run.

---

## Routes

```ruby
devise_for :users
resources :searches, only: [:new, :create, :show]
```

Devise registers: `/users/sign_in`, `/users/sign_up`, `/users/sign_out`, `/users/password/new`, `/users/password/edit`.

---

## Views

Devise views are generated into `app/views/devise/` and styled to match the existing Tailwind design (indigo/gray palette, rounded-xl cards, consistent typography).

Views to generate and style:
- `sessions/new` — sign-in form
- `registrations/new` — sign-up form
- `passwords/new` — forgot password form
- `passwords/edit` — reset password form (via email link)

A minimal nav element is added to the application layout with a sign-out link for authenticated users, consistent with the existing page style.

### Turbo-aware sign-out

Devise's sign-out uses `DELETE /users/sign_out` by default. With Turbo, plain `<a>` tags issue `GET`, so sign-out must use `data-turbo-method: :delete`:

```erb
<%= link_to "Sign out", destroy_user_session_path, data: { turbo_method: :delete } %>
```

---

## Testing

Add Devise test helpers to `spec/support/devise.rb`:

```ruby
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end
```

Update the `:user` factory to include a default password (required by `validatable`):

```ruby
factory :user do
  sequence(:email) { |n| "user#{n}@example.com" }
  password { "password123" }
end
```

Specs to write (request specs):
- Unauthenticated `GET /searches/new` redirects to sign in
- Unauthenticated `POST /searches` redirects to sign in
- Unauthenticated `GET /searches/:id` redirects to sign in
- Authenticated user can access `searches#new`
- Authenticated user cannot access another user's `searches#show` (IDOR)

Devise internals (registration, password reset flow) are not spec'd — the gem is trusted.

---

## Out of Scope

- OAuth / "Sign in with Google"
- Email confirmation (`confirmable`)
- Account lockout (`lockable`)
- Invitation flows
- Landing page (separate future work)
- Cleanup of existing guest user rows in the database (deferred to pre-production cleanup)
