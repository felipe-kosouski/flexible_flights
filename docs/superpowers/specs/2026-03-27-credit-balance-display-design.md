# Credit Balance Display — Design Spec

**Date:** 2026-03-27
**Status:** Approved

---

## Problem

Users only see their credit balance when they hit the paywall (`/payments/new`). This means most users never know they have 1 free credit until they accidentally discover the payment page. The balance should be ambient — always visible without requiring navigation.

---

## Solution

A credit chip in the nav bar that shows the current balance at a glance, changes appearance as credits run low, and opens a dropdown on click with context and a purchase CTA.

---

## Chip: Placement and States

The chip sits in the authenticated nav, between "Search history" and "Profile":

```
[Logo]   Search history   [chip]   Profile   Sign out   [theme toggle]
```

The chip has three visual states based on `current_user.search_credits`:

| State   | Condition | Background | Text color | Label           |
| ------- | --------- | ---------- | ---------- | --------------- |
| healthy | ≥ 2       | `#e8f4f8`  | `#0D4A62`  | `N credits`     |
| low     | = 1       | `#fef3c7`  | `#b45309`  | `1 credit left` |
| empty   | = 0       | `#fee2e2`  | `#b91c1c`  | `No credits`    |

Typography: Space Grotesk, 12px, weight 600. Shape: pill (`border-radius: 99px`), `4px 12px` padding.

---

## Dropdown: Content

Clicking the chip opens a dropdown anchored below it. It closes on click-outside or Escape.

**Structure (all states):**

1. Label: `SEARCH CREDITS` — 11px, uppercase, muted
2. Balance number — 28px Space Grotesk 700, colored to match chip state
3. One-liner explainer:
   - Healthy/low: _"Each credit runs one Smart Search — one destination, flexible dates, stay-length range."_
   - Empty: _"You're out of credits. Buy a pack to run your next Smart Search."_
4. CTA button:
   - Healthy/low: `Buy more credits` → `GET /payments/new`
   - Empty: `Buy credits` → `GET /payments/new`

Button: accent orange (`#e8784c`), full-width, 8px radius, 13px semibold white text.

Dropdown border matches chip state: `#e4dfd8` (healthy), `#fde68a` (low), `#fca5a5` (empty).

Width: 220px. Shadow: `0 4px 16px rgba(0,0,0,0.08)`.

---

## Implementation

### Files to create

**`app/views/shared/_credit_chip.html.erb`**
Renders the chip button and the dropdown panel. All state logic comes from the helper. Uses `data-controller="credits-dropdown"` on the wrapper.

**`app/javascript/controllers/credits_dropdown_controller.js`**
Stimulus controller with:

- `toggle()` action — opens/closes the dropdown
- `hide()` action — closes on click-outside (bound to `document` via `@click.outside`)
- No network requests — all data is already server-rendered

### Files to modify

**`app/views/layouts/application.html.erb`**
Inside the `user_signed_in?` block, render `shared/credit_chip` between the search history link and the profile link.

**`app/helpers/application_helper.rb`** (or a dedicated `CreditChipHelper`)
Add `credit_chip_state(user)` returning `:healthy`, `:low`, or `:empty`. Used by the partial to drive CSS classes and copy.

### No controller changes needed

The credit count (`current_user.search_credits`) is already available in the layout via the Devise `current_user` helper. No new actions or routes required.

---

## Dark mode

The chip and dropdown use hardcoded hex values above for reference. In implementation, use the project's CSS custom properties (`--color-brand`, `--color-brand-light`, etc.) and Tailwind semantic classes (`bg-brand-light`, `text-brand`, etc.) so dark mode is handled automatically by the existing theme system. The amber and red states should use `fair`/`poor` signal colors from the design system token table.

---

## Out of scope

- Credit purchase history in the dropdown — not needed at this stage
- Profile page credits section — the nav chip covers the use case
- Any changes to the payments page — the chip links to the existing `/payments/new`
- Animations or transition effects on the chip

---

## Testing

- Helper spec: `spec/helpers/application_helper_spec.rb` — `credit_chip_state` returns the correct symbol for 0, 1, and N credits
- View spec or system spec: chip renders in nav when signed in, does not render when signed out
- View spec: correct state class applied for each credit count
