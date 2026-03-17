# User Profile — Design Spec

**Date:** 2026-03-17
**Status:** Approved

## Overview

Add a user profile page where authenticated users can update their personal information (first name, last name, email), change their password, and delete their account with soft confirmation.

## Data

### Migration

Add two columns to the `users` table:

| Column | Type | Constraints |
|--------|------|-------------|
| `first_name` | string | not null, default: `""` |
| `last_name` | string | not null, default: `""` |

No business logic changes to the `User` AR model beyond accepting the new attributes.

## Routing

```ruby
resource :profile, only: [:show, :update, :destroy]
```

Note: `resource` (singular) generates a singleton resource — routes use `profile_path` (not `profiles_path`), unlike the plural `resources` used elsewhere in the app.

| Method | Path | Action |
|--------|------|--------|
| GET | /profile | show |
| PATCH | /profile | update |
| DELETE | /profile | destroy |

The nav bar gains a "Profile" link pointing to `profile_path`. The existing plain email `<span>` is removed from the nav.

## Controller: `ProfileController`

Inherits from `ApplicationController`. All actions gated by `before_action :authenticate_user!`.

### `show`

Assigns `@presenter = ProfilePresenter.new(current_user)` and renders the profile view. No other logic.

### `update`

Reads a hidden `form_type` param to determine which form was submitted:

- **`personal_info`** — permitted params: `first_name`, `last_name`, `email`. Calls `current_user.update(permitted_params)`. No password required for email changes — this is an intentional product decision given that Devise `:confirmable` is not enabled and the app does not require current-password verification for email updates.
- **`password`** — permitted params: `current_password`, `password`, `password_confirmation`. Calls `current_user.update_with_password(permitted_params)` — a Devise method that validates `current_password` before applying any changes. If `current_password` is wrong, no attributes are updated and errors are placed on `:current_password`. If `current_password` is correct but the new password fails Devise's validations (e.g. too short), errors are placed on `:password` and/or `:password_confirmation`. All three fields are surfaced by `password_errors`.
- **Unknown / missing `form_type`** — redirect to `profile_path` with an alert: `"Invalid request."`. No changes are applied.

On success: `redirect_to profile_path, notice: "..."`.
On failure: assigns `@presenter = ProfilePresenter.new(current_user)` (the user object now carries validation errors) then re-renders `show`. The presenter surfaces errors to the correct form section.

### `destroy`

Reads `params[:confirmation_email]`. If it matches `current_user.email` (compare after calling `.downcase` on both sides):
1. Capture the user: `user = current_user`
2. `sign_out user` (sign out first, before the record is destroyed; after sign_out, `current_user` returns `nil`)
3. `user.destroy!` (raises `ActiveRecord::RecordNotDestroyed` on failure rather than silently returning false)
4. `redirect_to root_path, notice: "Your account has been deleted."`

If it does not match: `redirect_to profile_path, alert: "Email did not match. Account not deleted."`

## Presenter: `ProfilePresenter`

**File:** `app/presenters/profile_presenter.rb`

Initialized with a `User` AR record. Provides:

- `display_name` — returns `"#{first_name} #{last_name}".strip`; falls back to `email` if both name fields are blank. Handles partial names correctly: a user with only `last_name: "Doe"` produces `"Doe"` (leading space stripped); only `first_name: "Jane"` produces `"Jane"`. Used as the page heading on the profile view.
- `personal_info_errors` — errors on `first_name`, `last_name`, `email`. Errors on `:base` are intentionally excluded.
- `password_errors` — errors on `current_password`, `password`, `password_confirmation`. Errors on `:base` are intentionally excluded.

This is a plain Ruby object with no ActiveRecord dependency beyond attribute reads. Consistent with existing presenter pattern in the codebase (`app/presenters/`).

## View: `app/views/profile/show.html.erb`

Single page with three sections, styled with Tailwind consistent with the existing app UI. The page heading displays `@presenter.display_name`.

### Section 1 — Personal Info

Form fields: first name, last name, email.
Hidden field: `form_type: personal_info`.
Submits `PATCH /profile`.
Errors displayed via `@presenter.personal_info_errors`.

### Section 2 — Change Password

Form fields: current password, new password, new password confirmation.
Hidden field: `form_type: password`.
Submits `PATCH /profile`.
Errors displayed via `@presenter.password_errors`.

### Section 3 — Delete Account (Danger Zone)

Visually separated section at the bottom. Descriptive text explaining the action is irreversible. Input field for the user to type their email address. Submits `DELETE /profile`.

## Testing

| Layer | Approach |
|-------|----------|
| Controller (`spec/requests/profile_spec.rb`) | Stub `current_user`; test redirect paths and flash for all branches: `update` personal_info success/failure, `update` password success/failure, `update` unknown form_type, `destroy` email match, `destroy` email mismatch |
| Presenter (`spec/presenters/profile_presenter_spec.rb`) | Pure Ruby, no DB — test `display_name` fallback logic and error delegation |
| View | Not tested directly; covered by request specs |

Controller specs follow the existing pattern: repository/domain calls stubbed, AR not hit.

## Out of Scope

- Profile photo / avatar
- Additional preference fields (deferred to future iterations)
- Email reconfirmation flow (Devise `:confirmable` not enabled)
- Requiring current password for email changes (intentionally excluded — see `update` section)
