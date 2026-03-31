# Credit Balance Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the user's search credit balance in the nav as a chip that opens a dropdown with context and a purchase CTA.

**Architecture:** A server-rendered partial (`_credit_chip.html.erb`) is injected into the existing nav layout. A helper method (`credit_chip_state`) drives the three visual states (healthy / low / empty). A Stimulus controller (`credits_dropdown`) handles open/close/click-outside with no network requests — the balance is already available via `current_user` in the layout.

**Tech Stack:** Ruby on Rails 8, ERB partials, Tailwind CSS v4 (custom warm/brand/accent scale), Stimulus (Hotwire), RSpec request specs.

---

### Task 1: `credit_chip_state` helper

**Files:**
- Create: `spec/helpers/application_helper_spec.rb`
- Modify: `app/helpers/application_helper.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/helpers/application_helper_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#credit_chip_state" do
    it "returns :healthy for 5 credits" do
      user = build_stubbed(:user, search_credits: 5)
      expect(helper.credit_chip_state(user)).to eq(:healthy)
    end

    it "returns :healthy for exactly 2 credits" do
      user = build_stubbed(:user, search_credits: 2)
      expect(helper.credit_chip_state(user)).to eq(:healthy)
    end

    it "returns :low for exactly 1 credit" do
      user = build_stubbed(:user, search_credits: 1)
      expect(helper.credit_chip_state(user)).to eq(:low)
    end

    it "returns :empty for 0 credits" do
      user = build_stubbed(:user, search_credits: 0)
      expect(helper.credit_chip_state(user)).to eq(:empty)
    end
  end
end
```

- [ ] **Step 2: Run the spec — expect failure**

```bash
bundle exec rspec spec/helpers/application_helper_spec.rb
```

Expected: 4 failures — `undefined method 'credit_chip_state'`

- [ ] **Step 3: Add `credit_chip_state` to `ApplicationHelper`**

Open `app/helpers/application_helper.rb` and add the method inside the module (after the existing `credit_pack_meta` method):

```ruby
module ApplicationHelper
  def credit_pack_meta
    # ... existing method unchanged ...
  end

  def credit_chip_state(user)
    case user.search_credits
    when 0 then :empty
    when 1 then :low
    else        :healthy
    end
  end
end
```

- [ ] **Step 4: Run the spec — expect all green**

```bash
bundle exec rspec spec/helpers/application_helper_spec.rb
```

Expected: 4 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add spec/helpers/application_helper_spec.rb app/helpers/application_helper.rb
git commit -m "feat: add credit_chip_state helper"
```

---

### Task 2: Stimulus controller `credits-dropdown`

**Files:**
- Create: `app/javascript/controllers/credits_dropdown_controller.js`

> The controllers directory uses `eagerLoadControllersFrom` — any file matching `*_controller.js` is auto-registered. No changes to `index.js` needed.

- [ ] **Step 1: Create the controller**

Create `app/javascript/controllers/credits_dropdown_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Manages the credit chip dropdown in the nav.
// The dropdown is server-rendered and toggled with CSS (hidden class).
// Click-outside closes the dropdown via a window-level listener.
export default class extends Controller {
  static targets = ["dropdown"]

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}
```

- [ ] **Step 2: Verify the controller name maps correctly**

The file is named `credits_dropdown_controller.js`. Stimulus maps underscores to dashes, so it registers as `credits-dropdown`. The partial will use `data-controller="credits-dropdown"`. No further registration needed.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/credits_dropdown_controller.js
git commit -m "feat: add credits-dropdown Stimulus controller"
```

---

### Task 3: Credit chip partial

**Files:**
- Create: `app/views/shared/_credit_chip.html.erb`

The partial assumes it is rendered in a context where `current_user` and `credit_chip_state` are available (both are in the layout context).

- [ ] **Step 1: Create the partial**

Create `app/views/shared/_credit_chip.html.erb`:

```erb
<%
  state = credit_chip_state(current_user)

  chip_classes = case state
                 when :healthy then "bg-brand-50 text-brand-700"
                 when :low     then "bg-amber-100 text-amber-700"
                 when :empty   then "bg-red-100 text-red-700"
                 end

  chip_label = case state
               when :healthy then "#{current_user.search_credits} #{current_user.search_credits == 1 ? "credit" : "credits"}"
               when :low     then "1 credit left"
               when :empty   then "No credits"
               end

  dropdown_border = case state
                    when :healthy then "border-warm-200"
                    when :low     then "border-amber-300"
                    when :empty   then "border-red-300"
                    end

  balance_color = case state
                  when :healthy then "text-brand-700"
                  when :low     then "text-amber-700"
                  when :empty   then "text-red-700"
                  end

  explainer = state == :empty \
    ? "You're out of credits. Buy a pack to run your next Smart Search." \
    : "Each credit runs one Smart Search — one destination, flexible dates, stay-length range."

  cta_label = state == :empty ? "Buy credits" : "Buy more credits"
%>

<div class="relative"
     data-controller="credits-dropdown"
     data-action="click@window->credits-dropdown#hide">

  <button type="button"
          class="<%= chip_classes %> text-xs font-semibold px-3 py-1 rounded-full font-heading cursor-pointer"
          data-action="click->credits-dropdown#toggle"
          aria-label="<%= chip_label %> — click to manage">
    <%= chip_label %>
  </button>

  <div data-credits-dropdown-target="dropdown"
       class="hidden absolute right-0 top-full mt-2 w-56 bg-white rounded-xl border <%= dropdown_border %> shadow-lg z-50 p-4">

    <p class="text-[11px] font-semibold uppercase tracking-wider text-warm-500 mb-1">Search Credits</p>

    <p class="font-heading text-[28px] font-bold leading-none mb-2 <%= balance_color %>">
      <%= current_user.search_credits %>
    </p>

    <p class="text-sm text-warm-600 mb-4 leading-snug"><%= explainer %></p>

    <%= link_to new_payment_path,
          class: "block w-full text-center bg-accent-500 hover:bg-accent-600 text-white text-sm font-semibold py-2 rounded-lg transition-colors" do %>
      <%= cta_label %>
    <% end %>

  </div>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/shared/_credit_chip.html.erb
git commit -m "feat: add credit chip partial with dropdown"
```

---

### Task 4: Wire into nav + request specs

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `spec/requests/nav_credit_chip_spec.rb`

- [ ] **Step 1: Write the failing request specs**

Create `spec/requests/nav_credit_chip_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Nav credit chip", type: :request do
  describe "chip visibility" do
    it "does not render the chip when signed out" do
      get root_path
      expect(response.body).not_to include("Search Credits")
      expect(response.body).not_to include("credits-dropdown")
    end

    it "renders the chip when signed in" do
      user = create(:user, search_credits: 3)
      sign_in user
      get root_path
      expect(response.body).to include("credits-dropdown")
    end
  end

  describe "chip label per state" do
    before { sign_in user }

    context "when healthy (≥ 2 credits)" do
      let(:user) { create(:user, search_credits: 5) }

      it "shows the credit count" do
        get root_path
        expect(response.body).to include("5 credits")
      end
    end

    context "when low (1 credit)" do
      let(:user) { create(:user, search_credits: 1) }

      it "shows '1 credit left'" do
        get root_path
        expect(response.body).to include("1 credit left")
      end
    end

    context "when empty (0 credits)" do
      let(:user) { create(:user, search_credits: 0) }

      it "shows 'No credits'" do
        get root_path
        expect(response.body).to include("No credits")
      end
    end
  end

  describe "dropdown content" do
    it "includes a link to the payments page" do
      user = create(:user, search_credits: 3)
      sign_in user
      get root_path
      expect(response.body).to include(new_payment_path)
    end
  end
end
```

- [ ] **Step 2: Run the specs — expect failure**

```bash
bundle exec rspec spec/requests/nav_credit_chip_spec.rb
```

Expected: failures — chip not yet rendered in the layout

- [ ] **Step 3: Add the chip to the nav layout**

Open `app/views/layouts/application.html.erb`. Find the authenticated nav block (the `<% if user_signed_in? %>` section around line 57–65). Add the `render "shared/credit_chip"` call between the search history link and the profile link:

```erb
<% if user_signed_in? %>
  <div class="flex items-center gap-4 sm:gap-6">
    <%= link_to t("searches.history.title"), search_history_path,
          class: "hidden sm:block text-sm text-warm-500 hover:text-warm-900 transition-colors" %>
    <%= render "shared/credit_chip" %>
    <%= link_to t("profile.locale_label"), profile_path,
          class: "text-sm text-warm-500 hover:text-warm-900 transition-colors" %>
    <%= link_to t("devise.sessions.destroy.sign_out", default: "Sign out"), destroy_user_session_path,
          data: { turbo_method: :delete },
          class: "text-sm text-warm-500 hover:text-warm-900 transition-colors" %>
  </div>
<% else %>
```

- [ ] **Step 4: Run the specs — expect all green**

```bash
bundle exec rspec spec/requests/nav_credit_chip_spec.rb
```

Expected: 6 examples, 0 failures

- [ ] **Step 5: Run the full suite to check for regressions**

```bash
bundle exec rspec
```

Expected: all green

- [ ] **Step 6: Commit**

```bash
git add app/views/layouts/application.html.erb spec/requests/nav_credit_chip_spec.rb
git commit -m "feat: render credit chip in nav"
```
