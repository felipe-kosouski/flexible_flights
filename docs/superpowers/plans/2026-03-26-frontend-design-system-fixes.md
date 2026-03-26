# Frontend Design System Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all accessibility violations, design system inconsistencies, and dark mode gaps identified in the UI/UX review of `app/views` and `app/assets`.

**Architecture:** Pure view/CSS layer — no domain, controller, or model changes required. All fixes are additive HTML attribute changes, Tailwind class substitutions, or CSS additions. The approach respects the existing override-based dark mode strategy (CSS `!important` block targeting `[data-theme="dark"]`).

**Tech Stack:** Rails 8 ERB views, Tailwind CSS v4, Heroicons inline SVG, Turbo Streams (ActionCable)

---

## File Map

| File | Tasks |
|------|-------|
| `app/views/layouts/application.html.erb` | 1, 2, 7 |
| `app/views/searches/show.html.erb` | 1 |
| `app/views/searches/_failed.html.erb` | 1, 2, 5 |
| `app/views/searches/_loading.html.erb` | — (no changes) |
| `app/views/searches/_results.html.erb` | 6, 9, 10 |
| `app/views/searches/_flight_card.html.erb` | 3, 6, 8 |
| `app/views/searches/new.html.erb` | 4, 5 |
| `app/views/devise/sessions/new.html.erb` | 2, 4, 5 |
| `app/views/devise/registrations/new.html.erb` | 2, 4, 5 |
| `app/views/devise/passwords/new.html.erb` | 2, 4, 5 |
| `app/views/profile/show.html.erb` | 2, 4, 5 |
| `app/assets/tailwind/application.css` | 7, 8 |
| `docs/design-system.md` | 11 |

---

## Baseline

Before starting any task, establish that the test suite is green.

- [ ] **Run baseline check**

```bash
bundle exec rspec --format progress
```

Expected: all green. If anything fails, do not proceed — resolve first.

---

## Task 1: HTML Semantics (lang, skip link, aria-live, aria-hidden)

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/searches/show.html.erb`
- Modify: `app/views/searches/_failed.html.erb`

### What & Why

| Issue | Fix |
|-------|-----|
| `<html>` has no `lang` attribute | Screen readers can't determine language for TTS |
| No skip-to-content link | Keyboard users tab through nav on every page |
| Turbo Stream results replaced with no `aria-live` | Screen readers never announce search completion |
| Decorative SVGs in `show.html.erb` and `_failed.html.erb` lack `aria-hidden` | Screen readers read out SVG path data |

- [ ] **Step 1: Add `lang`, skip link, and `id="main-content"` to layout**

In `app/views/layouts/application.html.erb`, apply all three changes:

```erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <title><%= content_for(:title) || "Flexible Flights" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Flexible Flights">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%# Anti-FOUC: set [data-theme] on <html> before first paint to prevent flash. %>
    <script>
      (function() {
        var s = localStorage.getItem("theme");
        var d = !s && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : s;
        if (d) document.documentElement.dataset.theme = d;
      })();
    </script>

    <%= yield :head %>

    <%#= tag.link rel: "manifest", href: pwa_manifest_path(format: :json) %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="min-h-screen bg-warm-50 text-warm-900 font-body transition-colors duration-200">
    <a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-brand-600 focus:text-white focus:rounded-lg focus:text-sm focus:font-medium">
      Skip to content
    </a>
    <nav class="bg-white border-b border-warm-200">
```

Then further down, add `id="main-content"` to the `<main>` tag:

```erb
    <main id="main-content" class="<%= content_for?(:main_class) ? yield(:main_class) : "container mx-auto px-5 py-10 flex justify-center" %>">
      <%= yield %>
    </main>
```

- [ ] **Step 2: Wrap Turbo Stream target in `aria-live` region**

In `app/views/searches/show.html.erb`, wrap the results area in a stable live region. Turbo will replace `#search_results` (the inner div owned by each partial), while this outer div remains stable and announces changes to screen readers:

```erb
<% content_for :title, "Search Results — Flexible Flights" %>

<div class="w-full">
  <%# Back link %>
  <div class="mb-6">
    <%= link_to new_search_path, class: "inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 transition-colors" do %>
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
      </svg>
      New search
    <% end %>
  </div>

  <%# Subscribe to search run updates via ActionCable %>
  <%= turbo_stream_from "search_run_#{@search_run.id}" %>

  <%# aria-live wrapper is stable and never replaced. Turbo replaces #search_results inside it.
      Screen readers will announce content changes when the job completes. %>
  <div aria-live="polite" aria-atomic="false">
    <% if @search_run.completed? && @presenter %>
      <% if @presenter.low_confidence? %>
        <%= render "low_confidence", presenter: @presenter %>
      <% else %>
        <%= render "results", presenter: @presenter %>
      <% end %>
    <% elsif @search_run.failed? %>
      <%= render "failed", search_run: @search_run %>
    <% else %>
      <%= render "loading" %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 3: Add `aria-hidden` to error SVG in `_failed.html.erb`**

```erb
<div id="search_results" class="w-full flex flex-col items-center justify-center py-24 text-center">
  <div class="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mb-6">
    <svg class="w-6 h-6 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
    </svg>
  </div>
  <h2 class="text-lg font-medium text-gray-800"><%= t("searches.show.failed_title") %></h2>
  <p class="mt-1 text-sm text-gray-400"><%= t("searches.show.failed_body") %></p>
  <div class="mt-6">
    <%= link_to t("searches.show.try_again"), new_search_path, class: "inline-block bg-brand-700 hover:bg-brand-800 text-white text-sm font-medium rounded-lg px-5 py-2.5 transition-colors" %>
  </div>
</div>
```

- [ ] **Step 4: Verify tests still pass**

```bash
bundle exec rspec --format progress
```

Expected: all green (no view-layer specs to break, but confirms no Ruby errors introduced).


---

## Task 2: Touch Targets — Minimum 44px on All Interactive Controls

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/devise/sessions/new.html.erb`
- Modify: `app/views/devise/registrations/new.html.erb`
- Modify: `app/views/devise/passwords/new.html.erb`
- Modify: `app/views/searches/_failed.html.erb`
- Modify: `app/views/profile/show.html.erb`

All submit buttons and the theme toggle are below the 44px WCAG touch target minimum. The fix is `h-11` (44px) everywhere.

- [ ] **Step 1: Fix theme toggle in layout (`w-9 h-9` → `w-11 h-11`)**

In `app/views/layouts/application.html.erb`, change the theme toggle button size:

```erb
          <button data-controller="theme-toggle"
                  data-action="click->theme-toggle#toggle"
                  class="w-11 h-11 rounded-lg flex items-center justify-center text-warm-500 hover:text-warm-900 hover:bg-warm-100 transition-colors cursor-pointer"
                  aria-label="Toggle light/dark mode">
```

- [ ] **Step 2: Fix sign-in submit button**

In `app/views/devise/sessions/new.html.erb`, replace `py-2.5` with `h-11`:

```erb
        <%= f.submit "Sign in", class: "w-full bg-brand-700 hover:bg-brand-800 text-white text-sm font-semibold rounded-lg px-5 h-11 transition-colors cursor-pointer" %>
```

- [ ] **Step 3: Fix create account submit button**

In `app/views/devise/registrations/new.html.erb`, replace `py-2.5` with `h-11`:

```erb
        <%= f.submit "Create account", class: "w-full bg-brand-700 hover:bg-brand-800 text-white text-sm font-semibold rounded-lg px-5 h-11 transition-colors cursor-pointer" %>
```

- [ ] **Step 4: Fix password reset submit button**

In `app/views/devise/passwords/new.html.erb`, replace `py-2.5` with `h-11`:

```erb
        <%= f.submit "Send reset link", class: "w-full bg-brand-700 hover:bg-brand-800 text-white text-sm font-semibold rounded-lg px-5 h-11 transition-colors cursor-pointer" %>
```

- [ ] **Step 5: Fix failed state retry button**

In `app/views/searches/_failed.html.erb`, replace `py-2.5` with `h-11 inline-flex items-center`:

```erb
    <%= link_to t("searches.show.try_again"), new_search_path, class: "h-11 inline-flex items-center bg-brand-700 hover:bg-brand-800 text-white text-sm font-medium rounded-lg px-5 transition-colors" %>
```

- [ ] **Step 6: Fix profile page buttons (`py-2` → `h-11`)**

In `app/views/profile/show.html.erb`, there are three submit buttons. Apply `h-11` to all three (removing `py-2`):

Save changes button (line ~54):
```erb
      <%= submit_tag "Save changes",
            class: "bg-gray-900 text-white text-sm font-medium px-4 h-11 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer" %>
```

Update password button (line ~95):
```erb
      <%= submit_tag "Update password",
            class: "bg-gray-900 text-white text-sm font-medium px-4 h-11 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer" %>
```

Delete account button (line ~112):
```erb
      <%= submit_tag "Delete my account",
            class: "bg-red-600 text-white text-sm font-medium px-4 h-11 rounded-lg hover:bg-red-700 transition-colors cursor-pointer",
            data: { turbo_confirm: "Are you sure? This cannot be undone." } %>
```

- [ ] **Step 7: Verify tests still pass**

```bash
bundle exec rspec --format progress
```


---

## Task 3: Typography Minimum — Score Badge Text

**Files:**
- Modify: `app/views/searches/_flight_card.html.erb`

`text-[9px]` and `text-[10px]` are below the design system's 12px floor. Raise both to `text-xs` (12px).

- [ ] **Step 1: Replace sub-minimum text sizes in flight card**

In `app/views/searches/_flight_card.html.erb`, the score badge column (lines 9 and 11):

```erb
    <div class="flex-shrink-0 flex flex-col items-center gap-1.5 pt-0.5">
      <span class="text-xs font-medium text-gray-400">#<%= flight.rank %></span>
      <div class="w-12 h-12 rounded-full ring-2 flex flex-col items-center justify-center <%= flight.score_ring_class %>">
        <span class="text-base font-bold leading-none <%= flight.score_color_class %>"><%= flight.score %></span>
        <span class="text-xs font-medium leading-none text-gray-400 mt-0.5"><%= t("flights.labels.score") %></span>
      </div>
      <span class="text-xs font-medium <%= flight.score_color_class %>"><%= flight.score_label %></span>
    </div>
```

- [ ] **Step 2: Verify**

```bash
bundle exec rspec --format progress
```


---

## Task 4: Focus Ring Standardization

**Files:**
- Modify: `app/views/searches/new.html.erb`
- Modify: `app/views/devise/sessions/new.html.erb`
- Modify: `app/views/devise/registrations/new.html.erb`
- Modify: `app/views/devise/passwords/new.html.erb`
- Modify: `app/views/profile/show.html.erb`

**The standard:** `focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600`

- The opaque `focus:border-brand-600` is the primary WCAG-compliant focus indicator (#1a627c on white = ~7:1 contrast)
- The `focus:ring-brand-600/20` is a decorative glow only
- Remove `focus:border-transparent` everywhere — it was hiding the border on focus

**Find pattern across all files:**

Before: `focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent`
After: `focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600`

Before (profile): `focus:outline-none focus:ring-2 focus:ring-gray-900`
After: `focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600`

- [ ] **Step 1: Fix `searches/new.html.erb` — 8 inputs**

Replace every occurrence of `focus:ring-brand-500 focus:border-brand-500` with `focus:ring-brand-600/20 focus:border-brand-600` in `app/views/searches/new.html.erb`.

The search form uses `focus:ring-brand-500 focus:border-brand-500` on all inputs. Replace all 8 occurrences. Example (the pattern is identical for each input):

```erb
class="w-full bg-white rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600"
```

Apply this same class string to: origin input, destination input, earliest_departure date field, latest_return date field, min_stay_days number field, max_stay_days number field, max_stops select, luggage_requirement select.

- [ ] **Step 2: Fix `devise/sessions/new.html.erb` — 2 inputs**

Replace both occurrences of `focus:ring-brand-500 focus:border-transparent`:

Email field:
```erb
              class: "w-full rounded-lg border border-gray-300 px-3.5 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600"
```

Password field (same class string).

- [ ] **Step 3: Fix `devise/registrations/new.html.erb` — 3 inputs**

Replace all three `focus:ring-brand-500 focus:border-transparent` occurrences with the standard. Email, password, and password confirmation fields all get:

```erb
              class: "w-full rounded-lg border border-gray-300 px-3.5 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600"
```

- [ ] **Step 4: Fix `devise/passwords/new.html.erb` — 1 input**

Email field:
```erb
              class: "w-full rounded-lg border border-gray-300 px-3.5 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600"
```

- [ ] **Step 5: Fix `profile/show.html.erb` — 6 inputs**

Replace all `focus:ring-gray-900` occurrences:

First name, last name, email, preferred_locale select, current_password, new_password, password_confirmation — all get:

```erb
class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600"
```

The confirmation email (delete account section) with `focus:ring-red-500` stays as-is — red ring is intentional for the destructive confirmation field.

- [ ] **Step 6: Verify**

```bash
bundle exec rspec --format progress
```


---

## Task 5: Button Color Consistency

**Files:**
- Modify: `app/views/searches/new.html.erb`
- Modify: `app/views/searches/_failed.html.erb`
- Modify: `app/views/devise/sessions/new.html.erb`
- Modify: `app/views/devise/registrations/new.html.erb`
- Modify: `app/views/devise/passwords/new.html.erb`
- Modify: `app/views/profile/show.html.erb`

**Color rules from the design system:**

| Variant | Background | Use |
|---------|-----------|-----|
| Primary | `accent-500 hover:accent-600` | Core product actions (Search, Try again) |
| Secondary | `brand-600 hover:brand-700` | Auth form submits, Save, Update |
| Destructive | `red-600 hover:red-700` | Delete (already correct) |

**What changes:**
- Search submit: `brand-700` → `accent-500` (this IS the primary product action)
- Failed retry: `brand-700` → `accent-500` (retrying search = product action)
- Sign in / Create account / Send reset link: `brand-700` → `brand-600` (closer to spec secondary variant)
- Profile Save changes / Update password: `gray-900` → `brand-600` (off-brand → secondary)

- [ ] **Step 1: Fix search submit in `searches/new.html.erb`**

```erb
      <div class="pt-1">
        <%= f.submit t("searches.new.submit"),
              class: "w-full bg-accent-500 hover:bg-accent-600 active:bg-accent-700 text-white font-semibold rounded-lg px-6 h-11 text-sm transition-colors cursor-pointer" %>
      </div>
```

- [ ] **Step 2: Fix retry button in `_failed.html.erb`**

```erb
    <%= link_to t("searches.show.try_again"), new_search_path, class: "h-11 inline-flex items-center bg-accent-500 hover:bg-accent-600 text-white text-sm font-medium rounded-lg px-5 transition-colors" %>
```

- [ ] **Step 3: Fix sign-in submit in `devise/sessions/new.html.erb`**

```erb
        <%= f.submit "Sign in", class: "w-full bg-brand-600 hover:bg-brand-700 text-white text-sm font-semibold rounded-lg px-5 h-11 transition-colors cursor-pointer" %>
```

- [ ] **Step 4: Fix create account submit in `devise/registrations/new.html.erb`**

```erb
        <%= f.submit "Create account", class: "w-full bg-brand-600 hover:bg-brand-700 text-white text-sm font-semibold rounded-lg px-5 h-11 transition-colors cursor-pointer" %>
```

- [ ] **Step 5: Fix password reset submit in `devise/passwords/new.html.erb`**

```erb
        <%= f.submit "Send reset link", class: "w-full bg-brand-600 hover:bg-brand-700 text-white text-sm font-semibold rounded-lg px-5 h-11 transition-colors cursor-pointer" %>
```

- [ ] **Step 6: Fix profile Save changes and Update password buttons**

In `app/views/profile/show.html.erb`, change both `bg-gray-900 hover:bg-gray-700` buttons to brand:

Save changes:
```erb
      <%= submit_tag "Save changes",
            class: "bg-brand-600 text-white text-sm font-medium px-4 h-11 rounded-lg hover:bg-brand-700 transition-colors cursor-pointer" %>
```

Update password:
```erb
      <%= submit_tag "Update password",
            class: "bg-brand-600 text-white text-sm font-medium px-4 h-11 rounded-lg hover:bg-brand-700 transition-colors cursor-pointer" %>
```

The Delete account button (`bg-red-600`) is already correct — leave it.

- [ ] **Step 7: Verify**

```bash
bundle exec rspec --format progress
```


---

## Task 6: External Link Colors

**Files:**
- Modify: `app/views/searches/_flight_card.html.erb`
- Modify: `app/views/searches/_results.html.erb`

`text-blue-600` and `text-cyan-600` are off-brand. All external search links should use `text-brand-600 hover:text-brand-700`.

- [ ] **Step 1: Fix flight card external links**

In `app/views/searches/_flight_card.html.erb`, the Google Flights and Skyscanner links at the bottom of the card:

```erb
        <div class="mt-3 pt-3 border-t border-gray-100 flex items-center gap-4">
          <span class="text-xs text-gray-400"><%= t("flights.labels.search_this_flight") %></span>
          <%= link_to t("flights.labels.google_flights"), flight.search_urls.google_flights_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-brand-600 hover:text-brand-700 hover:underline" %>
          <%= link_to t("flights.labels.skyscanner"), flight.search_urls.skyscanner_url,
                target: "_blank", rel: "noopener noreferrer",
                class: "text-xs font-medium text-brand-600 hover:text-brand-700 hover:underline" %>
        </div>
```

- [ ] **Step 2: Fix results page external links (best time sub-card)**

In `app/views/searches/_results.html.erb`, the `btt` (best time) sub-card search links around line 100:

```erb
                  <%= link_to t("flights.labels.google_flights"), btt.search_urls.google_flights_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-brand-600 hover:text-brand-700 hover:underline" %>
                  <%= link_to t("flights.labels.skyscanner"), btt.search_urls.skyscanner_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-brand-600 hover:text-brand-700 hover:underline" %>
```

The `ccw` (cheapest comfort window) sub-card links (around line 130) will be fixed in Task 10 alongside the purple → amber color change.

- [ ] **Step 3: Verify**

```bash
bundle exec rspec --format progress
```


---

## Task 7: Google Fonts Performance

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/assets/tailwind/application.css`

Loading fonts via CSS `@import url()` blocks CSS parsing until the font request resolves. Moving to `<link>` tags in `<head>` with `rel="preconnect"` allows the browser to initiate the connection earlier and in parallel.

- [ ] **Step 1: Add preconnect and font link tags to layout `<head>`**

In `app/views/layouts/application.html.erb`, add the font tags **before** the `stylesheet_link_tag` line:

```erb
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&display=swap" rel="stylesheet" />

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

- [ ] **Step 2: Remove the `@import url()` from `application.css`**

In `app/assets/tailwind/application.css`, delete line 1:

```diff
-@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&display=swap');
-
 @import "tailwindcss";
```

The fonts are now loaded by the `<link>` tag in HTML, so the CSS `@import` is redundant.

- [ ] **Step 3: Verify the app compiles and fonts still load**

```bash
bundle exec rspec --format progress
```

Then start the dev server and confirm Space Grotesk renders on headings and DM Sans on body:

```bash
bin/dev
```

Open `http://localhost:3000` and inspect the `<head>` to confirm the three font link tags are present and fonts load without FOIT.


---

## Task 8: Dark Mode Card Hover State

**Files:**
- Modify: `app/views/searches/_flight_card.html.erb`
- Modify: `app/assets/tailwind/application.css`

In dark mode, the CSS overrides `shadow-sm` to `box-shadow: none`, so `hover:shadow-sm` on flight cards produces no visible effect. We need a dark-mode-compatible hover indicator.

The `@custom-variant dark` in `application.css` enables the `dark:` Tailwind prefix. `bg-dark-surface-raised` is available via the `@theme` definition (`--color-dark-surface-raised: #1e2d3f`).

- [ ] **Step 1: Add dark mode hover class to flight card**

In `app/views/searches/_flight_card.html.erb`, add `dark:hover:bg-dark-surface-raised transition-colors` to the card wrapper (note: `transition-colors` is added since we're now transitioning background in addition to shadow):

```erb
<div class="rounded-xl border border-gray-200 bg-white p-5 hover:shadow-sm dark:hover:bg-dark-surface-raised transition-shadow transition-colors">
```

- [ ] **Step 2: Verify the dark mode override in CSS doesn't conflict**

The existing CSS has:
```css
[data-theme="dark"] .shadow-sm  { box-shadow: none !important; ... }
```

This overrides `shadow-sm` globally but does NOT override `bg-dark-surface-raised` — they are independent properties. The background hover will work correctly.

Run tests:
```bash
bundle exec rspec --format progress
```


---

## Task 9: Tailwind v4 Opacity Syntax Migration

**Files:**
- Modify: `app/views/searches/_results.html.erb`

Tailwind v4 deprecates `bg-opacity-*` and `border-opacity-*` in favor of the `/` modifier syntax. Replace all occurrences in `_results.html.erb`.

- [ ] **Step 1: Replace `bg-opacity-*` with `/` notation**

In `app/views/searches/_results.html.erb`:

| Find | Replace |
|------|---------|
| `bg-white bg-opacity-40` | `bg-white/40` |
| `bg-white bg-opacity-50` | `bg-white/50` |
| `bg-amber-100 text-amber-700` (the confidence badge) | no change needed — no opacity there |

- [ ] **Step 2: Replace `border-opacity-*` with `/` notation**

| Find | Replace |
|------|---------|
| `border border-brand-200 border-opacity-60` | `border border-brand-200/60` |
| `border-t border-brand-200 border-opacity-40` | `border-t border-brand-200/40` |

Note: the purple border opacity lines will be fixed in Task 10.

- [ ] **Step 3: Verify**

```bash
bundle exec rspec --format progress
```


---

## Task 10: CCW Card — Replace Purple with Amber

**Files:**
- Modify: `app/views/searches/_results.html.erb`

Purple is not in the design system, has no dark mode CSS override, and no semantic meaning in the token table. The home page "comfort window" insight card uses amber — align results to match.

- [ ] **Step 1: Replace all purple classes in the `ccw` sub-card**

In `app/views/searches/_results.html.erb`, the CCW block (around line 111):

Before:
```erb
            <div class="bg-white bg-opacity-50 rounded-xl p-4 text-purple-900 border border-purple-200 border-opacity-60">
              <div class="flex items-center justify-between gap-2 mb-2">
                <p class="text-xs font-bold uppercase tracking-wide opacity-60"><%= t("insights.best_value_label") %></p>
                <% if ccw.medium_confidence? %>
                  <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-amber-100 text-amber-700"><%= t("insights.confidence.medium") %></span>
                <% end %>
              </div>
              <p class="text-base font-bold"><%= ccw.date_range %></p>
              <% if ccw.description %>
                <p class="mt-1 text-xs opacity-75"><%= ccw.description %></p>
              <% end %>
              <p class="mt-1 text-xs opacity-60">
                Balances price and comfort &middot; avg. score <%= ccw.average_score %>/100
              </p>
              <% if ccw.search_urls %>
                <div class="mt-3 pt-3 border-t border-purple-200 border-opacity-40 flex items-center gap-3">
                  <span class="text-xs opacity-50"><%= t("flights.labels.search_this_flight") %></span>
                  <%= link_to t("flights.labels.google_flights"), ccw.search_urls.google_flights_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-purple-700 hover:underline" %>
                  <%= link_to t("flights.labels.skyscanner"), ccw.search_urls.skyscanner_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-purple-700 hover:underline" %>
                </div>
              <% end %>
            </div>
```

After:
```erb
            <div class="bg-white/50 rounded-xl p-4 text-amber-900 border border-amber-200/60">
              <div class="flex items-center justify-between gap-2 mb-2">
                <p class="text-xs font-bold uppercase tracking-wide opacity-60"><%= t("insights.best_value_label") %></p>
                <% if ccw.medium_confidence? %>
                  <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-amber-100 text-amber-700"><%= t("insights.confidence.medium") %></span>
                <% end %>
              </div>
              <p class="text-base font-bold"><%= ccw.date_range %></p>
              <% if ccw.description %>
                <p class="mt-1 text-xs opacity-75"><%= ccw.description %></p>
              <% end %>
              <p class="mt-1 text-xs opacity-60">
                Balances price and comfort &middot; avg. score <%= ccw.average_score %>/100
              </p>
              <% if ccw.search_urls %>
                <div class="mt-3 pt-3 border-t border-amber-200/40 flex items-center gap-3">
                  <span class="text-xs opacity-50"><%= t("flights.labels.search_this_flight") %></span>
                  <%= link_to t("flights.labels.google_flights"), ccw.search_urls.google_flights_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-brand-600 hover:text-brand-700 hover:underline" %>
                  <%= link_to t("flights.labels.skyscanner"), ccw.search_urls.skyscanner_url,
                        target: "_blank", rel: "noopener noreferrer",
                        class: "text-xs font-medium text-brand-600 hover:text-brand-700 hover:underline" %>
                </div>
              <% end %>
            </div>
```

Note: the search links in this block also get the brand color fix (completing Task 6 for this section).

- [ ] **Step 2: Verify**

```bash
bundle exec rspec --format progress
```


---

## Task 11: Design System Documentation Gaps

**Files:**
- Modify: `docs/design-system.md`

Five gaps were found in the design system doc that will cause future inconsistencies if not documented. No code changes — documentation only.

- [ ] **Step 1: Fix focus ring spec**

In the **Accessibility Standards** section, update the focus ring example:

Before:
```
- Focus rings: `ring-2 ring-brand-600/50` — always visible, never removed
```

After:
```
- Focus rings: `focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600` — always visible, never removed. The border provides the primary WCAG-compliant indicator (opaque); the ring is a decorative glow only.
```

- [ ] **Step 2: Add `prefers-reduced-motion` implementation**

At the end of the **Animation & Transitions** section, add:

```markdown
**Implementation (`application.css`):**

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

Or use Tailwind's `motion-reduce:` variant on individual elements:
`motion-reduce:transition-none motion-reduce:animate-none`
```

- [ ] **Step 3: Add UI Feedback Colors section**

After the **Semantic Signal Colors** table, add a new section:

```markdown
### UI Feedback Colors (Forms & Application State)

These are distinct from flight score signal colors. Use for form validation, toasts, and system messages.

| State   | Light bg    | Light text  | Dark bg    | Dark text  | Use                         |
| ------- | ----------- | ----------- | ---------- | ---------- | --------------------------- |
| `error` | `red-50`    | `red-800`   | `#1c0606`  | `red-300`  | Validation errors, alerts   |
| `success` | `green-50` | `green-800` | `#052e16`  | `green-300` | Save confirmation, toasts  |

Flash messages (notice/alert) in `application.html.erb` use `brand-50/brand-700` and `red-50/red-800` respectively — these match this table.
```

- [ ] **Step 4: Add Disabled State section**

Add to the **Component Patterns** section, after Buttons:

```markdown
### Disabled States

All disabled interactive elements follow this pattern:

- Opacity: `opacity-50`
- Cursor: `cursor-not-allowed`
- Pointer events: `pointer-events-none`
- Semantic: `disabled` attribute on the element

Example:
```erb
<button disabled class="... opacity-50 cursor-not-allowed pointer-events-none">
  Submit
</button>
```
```

- [ ] **Step 5: Add Breakpoints section**

Add to the **Spacing & Layout** section:

```markdown
**Breakpoints (mobile-first):**

| Breakpoint | Min-width | Use                              |
| ---------- | --------- | -------------------------------- |
| `sm`       | 640px     | Two-column grids, wider nav text |
| `md`       | 768px     | Three-column layouts             |
| `lg`       | 1024px    | Wide content, side-by-side views |
| `xl`       | 1280px    | Max-width containers             |

Always design mobile-first: base classes target ≤639px, then layer `sm:`, `md:` up.
```

- [ ] **Step 6: Document the gray/warm token equivalence**

Add a note at the top of the **Color System** section:

```markdown
> **Implementation note:** Views may use Tailwind's built-in `gray-*` scale OR the custom `warm-*` scale. Both are supported — `application.css` maps `gray-*` → `warm-*` equivalents in dark mode via CSS overrides. New code should prefer `warm-*` for semantic clarity. Never mix `gray-*` and `warm-*` within the same component.
```

- [ ] **Step 7: Verify no rspec regressions from doc-only change**

```bash
bundle exec rspec --format progress
```


---

## Final Verification

- [ ] **Run full test suite**

```bash
bundle exec rspec
```

Expected: all green.

- [ ] **Run linter**

```bash
bin/rubocop --no-pager
```

Expected: no new offenses (ERB changes are not linted by RuboCop, but any accidental Ruby changes would be caught).

- [ ] **Manual browser check checklist**

Start the dev server:
```bash
bin/dev
```

Check each of the following:

| Check | Where |
|-------|-------|
| Tab key → skip link appears at top-left | Any page |
| Tab key navigates form fields with visible brand-color border focus | `/users/sign_in`, `/searches/new` |
| Theme toggle is visibly larger (44px) in nav | Any page |
| Search submit button is amber/orange | `/searches/new` |
| Sign-in submit is teal (brand-600) | `/users/sign_in` |
| Profile save buttons are teal | `/profile` |
| Flight card score labels readable (not tiny) | Search results |
| Flight card hover shows background change in dark mode | Search results with dark mode on |
| CCW card is amber, not purple | Search results |
| External links (Google Flights, Skyscanner) are teal | Search results |
| Fonts load without FOIT (no text flash) | Page load |

---

## Out of Scope (Separate Work)

The following were identified in the review but are not included here — they require more context or cross-cutting decisions:

- **Hard-coded English strings** in `_results.html.erb` (i18n work — separate task)
- **Semi-transparent overlay contrast** (`bg-white/40` on colored cards) — needs designer decision on readable alternative
- **`font-extrabold` on recommendation directive** — needs copy/hierarchy review before changing weight
- **Score badge size** (`w-12` vs spec's `w-10`) — minor, needs visual sign-off
