# User Profile Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/profile` page where authenticated users can update personal info (first/last name, email), change their password, and delete their account with soft email confirmation.

**Architecture:** Custom `ProfileController` (singular resource) with `show`, `update`, and `destroy` actions. A plain Ruby `ProfilePresenter` wraps display logic and error surfacing. All profile concerns live outside Devise's controller hierarchy. The `update` action dispatches on a hidden `form_type` param to handle two independent forms on one page.

**Tech Stack:** Rails 8.1.2, Devise (database_authenticatable, registerable, validatable), Tailwind CSS, RSpec + FactoryBot

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `db/migrate/TIMESTAMP_add_name_to_users.rb` | Create | Add `first_name`, `last_name` columns to `users` |
| `spec/factories/users.rb` | Modify | Add `first_name`, `last_name` defaults to factory |
| `app/presenters/profile_presenter.rb` | Create | `display_name`, `personal_info_errors`, `password_errors` |
| `spec/presenters/profile_presenter_spec.rb` | Create | Pure Ruby presenter tests (no DB) |
| `config/routes.rb` | Modify | Add `resource :profile, only: [:show, :update, :destroy]` |
| `app/controllers/profile_controller.rb` | Create | `show`, `update`, `destroy` actions |
| `spec/requests/profile_spec.rb` | Create | Request specs for all branches |
| `app/views/profile/show.html.erb` | Create | Single-page profile with 3 sections |
| `app/views/layouts/application.html.erb` | Modify | Replace email span with Profile nav link |

---

### Task 1: Migration — add first_name and last_name to users

**Files:**
- Create: `db/migrate/TIMESTAMP_add_name_to_users.rb`
- Modify: `spec/factories/users.rb`

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration AddNameToUsers first_name:string last_name:string
```

- [ ] **Step 2: Edit the generated migration to add null: false and defaults**

Open the generated file at `db/migrate/YYYYMMDDHHMMSS_add_name_to_users.rb` and replace its content:

```ruby
# frozen_string_literal: true

class AddNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :first_name, :string, null: false, default: ""
    add_column :users, :last_name,  :string, null: false, default: ""
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
bin/rails db:migrate
```

Expected: completes without error; `db/schema.rb` now shows `first_name` and `last_name` on `users`.

- [ ] **Step 4: Update the user factory**

In `spec/factories/users.rb`, add the two new fields:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password  { "password123" }
    first_name { "Jane" }
    last_name  { "Doe" }
  end
end
```

- [ ] **Step 5: Verify all existing specs still pass**

```bash
bundle exec rspec
```

Expected: green — adding columns with defaults is non-breaking.

- [ ] **Step 6: Commit**

```bash
git add db/migrate/ db/schema.rb spec/factories/users.rb
git commit -m "feat: add first_name and last_name to users"
```

---

### Task 2: ProfilePresenter (TDD)

**Files:**
- Create: `spec/presenters/profile_presenter_spec.rb`
- Create: `app/presenters/profile_presenter.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/presenters/profile_presenter_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfilePresenter do
  let(:errors) { instance_double(ActiveModel::Errors) }

  def build_presenter(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
    user = instance_double(User,
      first_name: first_name,
      last_name:  last_name,
      email:      email,
      errors:     errors)
    described_class.new(user)
  end

  describe "#display_name" do
    it "returns full name when both fields are set" do
      expect(build_presenter.display_name).to eq("Jane Doe")
    end

    it "returns only first name when last name is blank" do
      expect(build_presenter(last_name: "").display_name).to eq("Jane")
    end

    it "returns only last name when first name is blank" do
      expect(build_presenter(first_name: "").display_name).to eq("Doe")
    end

    it "falls back to email when both name fields are blank" do
      expect(build_presenter(first_name: "", last_name: "").display_name).to eq("jane@example.com")
    end
  end

  describe "#personal_info_errors" do
    it "returns full messages for first_name, last_name, and email" do
      allow(errors).to receive(:full_messages_for).with(:first_name).and_return(["First name can't be blank"])
      allow(errors).to receive(:full_messages_for).with(:last_name).and_return([])
      allow(errors).to receive(:full_messages_for).with(:email).and_return([])

      expect(build_presenter.personal_info_errors).to eq(["First name can't be blank"])
    end

    it "returns empty array when there are no errors" do
      allow(errors).to receive(:full_messages_for).with(:first_name).and_return([])
      allow(errors).to receive(:full_messages_for).with(:last_name).and_return([])
      allow(errors).to receive(:full_messages_for).with(:email).and_return([])

      expect(build_presenter.personal_info_errors).to eq([])
    end
  end

  describe "#password_errors" do
    it "returns full messages for current_password, password, and password_confirmation" do
      allow(errors).to receive(:full_messages_for).with(:current_password).and_return(["Current password is invalid"])
      allow(errors).to receive(:full_messages_for).with(:password).and_return([])
      allow(errors).to receive(:full_messages_for).with(:password_confirmation).and_return([])

      expect(build_presenter.password_errors).to eq(["Current password is invalid"])
    end

    it "returns empty array when there are no errors" do
      allow(errors).to receive(:full_messages_for).with(:current_password).and_return([])
      allow(errors).to receive(:full_messages_for).with(:password).and_return([])
      allow(errors).to receive(:full_messages_for).with(:password_confirmation).and_return([])

      expect(build_presenter.password_errors).to eq([])
    end
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
bundle exec rspec spec/presenters/profile_presenter_spec.rb
```

Expected: FAIL — `uninitialized constant ProfilePresenter`

- [ ] **Step 3: Implement ProfilePresenter**

Create `app/presenters/profile_presenter.rb`:

```ruby
# frozen_string_literal: true

class ProfilePresenter
  PERSONAL_INFO_FIELDS = %i[first_name last_name email].freeze
  PASSWORD_FIELDS = %i[current_password password password_confirmation].freeze

  def initialize(user)
    @user = user
  end

  def display_name
    name = "#{@user.first_name} #{@user.last_name}".strip
    name.present? ? name : @user.email
  end

  def personal_info_errors
    PERSONAL_INFO_FIELDS.flat_map { |field| @user.errors.full_messages_for(field) }
  end

  def password_errors
    PASSWORD_FIELDS.flat_map { |field| @user.errors.full_messages_for(field) }
  end
end
```

- [ ] **Step 4: Run the spec to confirm it passes**

```bash
bundle exec rspec spec/presenters/profile_presenter_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/presenters/profile_presenter.rb spec/presenters/profile_presenter_spec.rb
git commit -m "feat: add ProfilePresenter with display_name and error helpers"
```

---

### Task 3: Routes, Controller, and Request Spec (TDD)

**Files:**
- Modify: `config/routes.rb`
- Create: `spec/requests/profile_spec.rb`
- Create: `app/controllers/profile_controller.rb`

- [ ] **Step 1: Add the route so request specs can resolve profile_path**

In `config/routes.rb`, add `resource :profile` before the health check line:

```ruby
Rails.application.routes.draw do
  devise_for :users
  root "searches#new"

  resources :searches, only: [ :new, :create, :show ]

  get "history", to: "search_history#index", as: :search_history

  resource :profile, only: [ :show, :update, :destroy ]

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 2: Write the failing request spec**

Create `spec/requests/profile_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profile", type: :request do
  let(:user) { create(:user, first_name: "Jane", last_name: "Doe", email: "jane@example.com", password: "password123") }

  describe "authentication guard" do
    it "redirects GET /profile to sign in when not signed in" do
      get profile_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects PATCH /profile to sign in when not signed in" do
      patch profile_path, params: { form_type: "personal_info", user: { email: "x@example.com" } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects DELETE /profile to sign in when not signed in" do
      delete profile_path, params: { confirmation_email: "jane@example.com" }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /profile" do
    before { sign_in user }

    it "returns 200" do
      get profile_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the user display name as the page heading" do
      get profile_path
      expect(response.body).to include("Jane Doe")
    end
  end

  describe "PATCH /profile — personal_info" do
    before { sign_in user }

    context "with valid params" do
      it "updates the user and redirects to profile_path" do
        patch profile_path, params: {
          form_type: "personal_info",
          user: { first_name: "John", last_name: "Smith", email: "john@example.com" }
        }
        expect(response).to redirect_to(profile_path)
        follow_redirect!
        expect(response.body).to include("John Smith")
      end
    end

    context "with invalid params (blank email)" do
      it "re-renders the profile form with status 422" do
        patch profile_path, params: {
          form_type: "personal_info",
          user: { first_name: "Jane", last_name: "Doe", email: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /profile — password" do
    before { sign_in user }

    context "with correct current password and a valid new password" do
      it "updates the password and redirects to profile_path" do
        patch profile_path, params: {
          form_type: "password",
          user: { current_password: "password123", password: "newpassword456", password_confirmation: "newpassword456" }
        }
        expect(response).to redirect_to(profile_path)
      end
    end

    context "with wrong current password" do
      it "re-renders the profile form with status 422" do
        patch profile_path, params: {
          form_type: "password",
          user: { current_password: "wrongpassword", password: "newpassword456", password_confirmation: "newpassword456" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with mismatched password confirmation" do
      it "re-renders the profile form with status 422" do
        patch profile_path, params: {
          form_type: "password",
          user: { current_password: "password123", password: "newpassword456", password_confirmation: "different999" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /profile — unknown form_type" do
    before { sign_in user }

    it "redirects to profile_path with an alert" do
      patch profile_path, params: { form_type: "unknown" }
      expect(response).to redirect_to(profile_path)
      follow_redirect!
      expect(response.body).to include("Invalid request")
    end
  end

  describe "DELETE /profile" do
    before { sign_in user }

    context "when confirmation email matches (case-insensitive)" do
      it "destroys the account and redirects to root_path" do
        delete profile_path, params: { confirmation_email: "jane@example.com" }
        expect(response).to redirect_to(root_path)
        expect(User.exists?(user.id)).to be false
      end

      it "invalidates the session so subsequent authenticated requests redirect to sign in" do
        delete profile_path, params: { confirmation_email: "jane@example.com" }
        get profile_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when confirmation email does not match" do
      it "redirects to profile_path with an alert and preserves the account" do
        delete profile_path, params: { confirmation_email: "wrong@example.com" }
        expect(response).to redirect_to(profile_path)
        expect(User.exists?(user.id)).to be true
      end
    end
  end
end
```

- [ ] **Step 3: Run the spec to confirm it fails**

```bash
bundle exec rspec spec/requests/profile_spec.rb
```

Expected: FAIL — `uninitialized constant ProfileController`

- [ ] **Step 4: Implement ProfileController**

Create `app/controllers/profile_controller.rb`:

```ruby
# frozen_string_literal: true

class ProfileController < ApplicationController
  before_action :authenticate_user!

  def show
    @presenter = ProfilePresenter.new(current_user)
  end

  def update
    case params[:form_type]
    when "personal_info" then update_personal_info
    when "password"      then update_password
    else
      redirect_to profile_path, alert: "Invalid request."
    end
  end

  def destroy
    if params[:confirmation_email].to_s.downcase == current_user.email.downcase
      user = current_user
      sign_out user
      user.destroy!
      redirect_to root_path, notice: "Your account has been deleted."
    else
      redirect_to profile_path, alert: "Email did not match. Account not deleted."
    end
  end

  private

  def update_personal_info
    if current_user.update(personal_info_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      @presenter = ProfilePresenter.new(current_user)
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    if current_user.update_with_password(password_params)
      # bypass_sign_in prevents Devise from signing the user out after a password change
      bypass_sign_in(current_user)
      redirect_to profile_path, notice: "Password updated."
    else
      @presenter = ProfilePresenter.new(current_user)
      render :show, status: :unprocessable_entity
    end
  end

  def personal_info_params
    params.require(:user).permit(:first_name, :last_name, :email)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
```

- [ ] **Step 5: Run the request spec to confirm it passes**

```bash
bundle exec rspec spec/requests/profile_spec.rb
```

Expected: all examples pass.

- [ ] **Step 6: Run the full suite to check for regressions**

```bash
bundle exec rspec
```

Expected: all specs pass.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/profile_controller.rb spec/requests/profile_spec.rb
git commit -m "feat: add ProfileController with show, update, and destroy"
```

---

### Task 4: Profile view

**Files:**
- Create: `app/views/profile/show.html.erb`

- [ ] **Step 1: Create the view**

Create `app/views/profile/show.html.erb`:

```erb
<div class="w-full max-w-lg space-y-8">
  <h1 class="text-2xl font-semibold text-gray-900"><%= @presenter.display_name %></h1>

  <%# Section 1 — Personal Info %>
  <div class="bg-white rounded-xl border border-gray-200 p-6 space-y-4">
    <h2 class="text-base font-medium text-gray-900">Personal information</h2>

    <% if @presenter.personal_info_errors.any? %>
      <ul class="rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-800 space-y-1">
        <% @presenter.personal_info_errors.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    <% end %>

    <%= form_with url: profile_path, method: :patch, class: "space-y-4" do |f| %>
      <%= hidden_field_tag :form_type, "personal_info" %>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <%= label_tag :first_name, "First name", class: "block text-sm font-medium text-gray-700 mb-1" %>
          <%= text_field_tag "user[first_name]", current_user.first_name,
                class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900",
                autocomplete: "given-name" %>
        </div>
        <div>
          <%= label_tag :last_name, "Last name", class: "block text-sm font-medium text-gray-700 mb-1" %>
          <%= text_field_tag "user[last_name]", current_user.last_name,
                class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900",
                autocomplete: "family-name" %>
        </div>
      </div>

      <div>
        <%= label_tag :email, "Email", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= email_field_tag "user[email]", current_user.email,
              class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900",
              autocomplete: "email" %>
      </div>

      <%= submit_tag "Save changes",
            class: "bg-gray-900 text-white text-sm font-medium px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer" %>
    <% end %>
  </div>

  <%# Section 2 — Change Password %>
  <div class="bg-white rounded-xl border border-gray-200 p-6 space-y-4">
    <h2 class="text-base font-medium text-gray-900">Change password</h2>

    <% if @presenter.password_errors.any? %>
      <ul class="rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-800 space-y-1">
        <% @presenter.password_errors.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    <% end %>

    <%= form_with url: profile_path, method: :patch, class: "space-y-4" do |f| %>
      <%= hidden_field_tag :form_type, "password" %>

      <div>
        <%= label_tag :current_password, "Current password", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= password_field_tag "user[current_password]", nil,
              class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900",
              autocomplete: "current-password" %>
      </div>

      <div>
        <%= label_tag :password, "New password", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= password_field_tag "user[password]", nil,
              class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900",
              autocomplete: "new-password" %>
      </div>

      <div>
        <%= label_tag :password_confirmation, "Confirm new password", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= password_field_tag "user[password_confirmation]", nil,
              class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900",
              autocomplete: "new-password" %>
      </div>

      <%= submit_tag "Update password",
            class: "bg-gray-900 text-white text-sm font-medium px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer" %>
    <% end %>
  </div>

  <%# Section 3 — Delete Account %>
  <div class="bg-white rounded-xl border border-red-200 p-6 space-y-4">
    <h2 class="text-base font-medium text-red-700">Delete account</h2>
    <p class="text-sm text-gray-600">This action is permanent and cannot be undone. All your searches and history will be deleted.</p>
    <p class="text-sm text-gray-600">Type your email address to confirm: <span class="font-medium"><%= current_user.email %></span></p>

    <%= form_with url: profile_path, method: :delete, class: "space-y-4" do |f| %>
      <%= email_field_tag :confirmation_email, nil,
            placeholder: current_user.email,
            class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-500",
            autocomplete: "off" %>

      <%= submit_tag "Delete my account",
            class: "bg-red-600 text-white text-sm font-medium px-4 py-2 rounded-lg hover:bg-red-700 transition-colors cursor-pointer",
            data: { turbo_confirm: "Are you sure? This cannot be undone." } %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 2: Run the full suite**

```bash
bundle exec rspec
```

Expected: all specs pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/profile/
git commit -m "feat: add profile show view"
```

---

### Task 5: Nav update — add Profile link

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Replace the email span with a Profile link**

In `app/views/layouts/application.html.erb`, replace the entire `<% if user_signed_in? %>` block (lines 30–41):

Current:
```erb
<% if user_signed_in? %>
  <div class="flex items-center gap-6">
    <%= link_to "History", search_history_path,
          class: "text-sm text-gray-500 hover:text-gray-700 transition-colors" %>
    <div class="flex items-center gap-4">
      <span class="text-sm text-gray-500"><%= current_user.email %></span>
      <%= link_to "Sign out", destroy_user_session_path,
            data: { turbo_method: :delete },
            class: "text-sm text-gray-500 hover:text-gray-700 transition-colors" %>
    </div>
  </div>
<% end %>
```

Replace with:
```erb
<% if user_signed_in? %>
  <div class="flex items-center gap-6">
    <%= link_to "History", search_history_path,
          class: "text-sm text-gray-500 hover:text-gray-700 transition-colors" %>
    <div class="flex items-center gap-4">
      <%= link_to "Profile", profile_path,
            class: "text-sm text-gray-500 hover:text-gray-700 transition-colors" %>
      <%= link_to "Sign out", destroy_user_session_path,
            data: { turbo_method: :delete },
            class: "text-sm text-gray-500 hover:text-gray-700 transition-colors" %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 2: Run the full suite**

```bash
bundle exec rspec
```

Expected: all specs pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "feat: add Profile link to nav bar"
```
