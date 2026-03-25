# Flexible Flights — Design System

This document is the **single source of truth** for visual brand and design decisions.
Consult it before touching any view, stylesheet, or CSS token.

---

## Brand Identity

**Product essence:** Decision intelligence for flexible travelers. Not a flight search engine — an analytical advisor that tells you _when_ to fly and _whether_ to book now.

**Brand personality:**

- Precise and confident (not vague or hedging)
- Warm and human (not cold fintech)
- Smart but approachable (not intimidating)
- Focused and minimal (not cluttered)

**Visual metaphor:** A navigator reading conditions to chart the optimal route. Not planes, not globes, not ocean blue — instruments, horizons, data clarity.

---

## Logo

A minimal SVG mark: a horizontal baseline (horizon) with an ascending line ending in a filled circle (the signal point / optimal moment).

Lives at: `public/logo.svg`

The mark conveys: a flight path rising from a runway, a price chart reaching its optimal point, a navigator's signal.

**Usage rules:**

- On light backgrounds: use `#0D4A62` (brand teal)
- On dark backgrounds: use `#4B9AB8` (lighter teal)
- Never recolor to anything outside the brand palette
- Wordmark: "Flexible Flights" in Space Grotesk 600
- Minimum clear space: equal to the height of the mark on all sides

---

## Typography

### Font Stack

| Role         | Family                  | Weights            | Use                                      |
| ------------ | ----------------------- | ------------------ | ---------------------------------------- |
| Heading      | Space Grotesk           | 500, 600, 700      | Page titles, section headers, hero copy  |
| Body         | DM Sans                 | 300, 400, 500, 600 | All UI text, paragraphs, labels, buttons |
| Data/Numbers | Space Grotesk (tabular) | 500, 600, 700      | Scores, prices, percentiles, countdowns  |

**Why these fonts:**

- Space Grotesk has distinctive geometric quirks (unique `G`, `S`, `6`, `9`) — recognizable but not overused in SaaS
- DM Sans is a warmer, more characterful alternative to Inter — readable at small sizes, not clinical
- Both are Google Fonts, no hosting required

**Google Fonts import (add to layout `<head>`):**

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link
  href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&display=swap"
  rel="stylesheet"
/>
```

### Type Scale

| Token          | Size            | Weight  | Line Height | Use                             |
| -------------- | --------------- | ------- | ----------- | ------------------------------- |
| `text-display` | 48px / 3rem     | 700     | 1.1         | Landing page hero only          |
| `text-h1`      | 32px / 2rem     | 700     | 1.15        | Page titles                     |
| `text-h2`      | 24px / 1.5rem   | 600     | 1.2         | Section headers                 |
| `text-h3`      | 18px / 1.125rem | 600     | 1.3         | Card titles, subsections        |
| `text-body-lg` | 18px / 1.125rem | 400     | 1.6         | Lead paragraphs                 |
| `text-body`    | 16px / 1rem     | 400     | 1.6         | Default body text               |
| `text-body-sm` | 14px / 0.875rem | 400     | 1.5         | Secondary info, captions        |
| `text-label`   | 12px / 0.75rem  | 600     | 1.4         | Uppercase labels, badges, tags  |
| `text-data`    | varies          | 600–700 | 1.2         | Scores, prices, tabular numbers |

**Rule:** `text-label` must always use `uppercase tracking-wide` — it signals system/meta information.

### Anti-patterns (typography)

- Never use Inter, Roboto, Arial, or system-ui as the primary type family
- Never body text below 14px in production UI
- Never use letter-spacing on body text (only on `text-label`)

---

## Color System

### Philosophy

Two distinct modes (light and dark) built from the same underlying palette. Colors are defined as CSS custom properties on `:root` and overridden on `.dark` or `[data-theme="dark"]`.

**Core brand:** Deep teal (`#0D4A62`) as primary brand identity. Warm amber-orange (`#E8784C`) as action/CTA color.
**Semantic signals:** Emerald/blue/amber/red for flight scores and booking recommendations — these are functional, not brand.

### Light Mode Tokens

```css
/* Backgrounds */
--color-background: #fafaf8; /* Warm off-white — never pure #FFFFFF for page bg */
--color-surface: #ffffff; /* Cards, panels, modals */
--color-surface-muted: #f4f2ee; /* Subtle alternate rows, secondary panels */
--color-surface-raised: #ffffff; /* Elevated elements (dropdowns, popovers) */

/* Borders */
--color-border: #e4dfd8; /* Default borders, dividers */
--color-border-strong: #c9c2b8; /* Emphasized borders, focused inputs */

/* Text */
--color-text-primary: #1c1814; /* Warm near-black — headlines, important copy */
--color-text-secondary: #6e6760; /* Supporting text, metadata */
--color-text-muted: #9e9590; /* Placeholder, disabled, tertiary */
--color-text-inverse: #fafaf8; /* Text on dark/brand backgrounds */

/* Brand — Teal */
--color-brand: #0d4a62; /* Primary brand, nav links active, focus rings */
--color-brand-hover: #0b3d52; /* Hover state for brand elements */
--color-brand-light: #e8f4f8; /* Light tint — brand chip bg, subtle highlights */
--color-brand-muted: #a8cdd9; /* Muted teal for icons, secondary brand elements */

/* Accent — Amber Orange (CTA) */
--color-accent: #e8784c; /* Primary CTA buttons, key highlights */
--color-accent-hover: #d4602e; /* Hover state */
--color-accent-light: #fdf2ec; /* Accent chip bg */
--color-accent-text: #ffffff; /* Text on accent backgrounds */
```

### Dark Mode Tokens

```css
/* Backgrounds */
--color-background: #0e1219; /* Deep warm charcoal */
--color-surface: #151c26; /* Cards, panels */
--color-surface-muted: #1c2535; /* Secondary panels */
--color-surface-raised: #1e2d3f; /* Elevated dropdowns, popovers */

/* Borders */
--color-border: #283045; /* Default */
--color-border-strong: #3a4a60; /* Emphasized */

/* Text */
--color-text-primary: #ede9e4; /* Warm white */
--color-text-secondary: #948e87; /* Supporting */
--color-text-muted: #5e5850; /* Placeholder, disabled */
--color-text-inverse: #1c1814; /* Text on light backgrounds */

/* Brand — Teal (lightened for dark bg) */
--color-brand: #4b9ab8; /* Lighter teal readable on dark */
--color-brand-hover: #60aecb;
--color-brand-light: #0e2130; /* Dark tint for brand chips */
--color-brand-muted: #2a4f62;

/* Accent — Amber Orange */
--color-accent: #f09060; /* Lighter for dark bg */
--color-accent-hover: #faa880;
--color-accent-light: #2a1a0e; /* Dark tint for accent chips */
--color-accent-text: #1c1814; /* Dark text on light amber */
```

### Semantic Signal Colors (Functional — not brand)

These communicate flight score quality and booking recommendations. Do not use for brand identity.

| Semantic    | Light bg  | Light text | Dark bg   | Dark text | Meaning                   |
| ----------- | --------- | ---------- | --------- | --------- | ------------------------- |
| `excellent` | `#DCFCE7` | `#15803D`  | `#052E16` | `#4ADE80` | Score 80–100 / Book Now   |
| `good`      | `#DBEAFE` | `#1D4ED8`  | `#0F172A` | `#60A5FA` | Score 60–79 / Wait        |
| `fair`      | `#FEF3C7` | `#B45309`  | `#1C1505` | `#FCD34D` | Score 40–59 / Consider    |
| `poor`      | `#FEE2E2` | `#B91C1C`  | `#1C0606` | `#F87171` | Score < 40 / Insufficient |

These map exactly to the existing `RankedFlightPresenter` and `InsightsPresenter` color logic — keep in sync.

### Tailwind v4 CSS Configuration

In `app/assets/tailwind/application.css`, add under `@import "tailwindcss"`:

```css
@theme {
  /* Fonts */
  --font-heading: "Space Grotesk", sans-serif;
  --font-body: "DM Sans", sans-serif;

  /* Brand colors — Teal */
  --color-brand-50: #e8f4f8;
  --color-brand-100: #c5e3ee;
  --color-brand-200: #a8cdd9;
  --color-brand-300: #6ea8be;
  --color-brand-400: #4b9ab8; /* dark mode primary */
  --color-brand-500: #2a7a9e;
  --color-brand-600: #0d4a62; /* light mode primary */
  --color-brand-700: #0b3d52;
  --color-brand-800: #082e3e;
  --color-brand-900: #051e2a;

  /* Accent colors — Amber Orange */
  --color-accent-50: #fdf2ec;
  --color-accent-100: #fbdecb;
  --color-accent-200: #f5bf9a;
  --color-accent-300: #efa070;
  --color-accent-400: #f09060; /* dark mode CTA */
  --color-accent-500: #e8784c; /* light mode CTA */
  --color-accent-600: #d4602e;
  --color-accent-700: #b44e24;
  --color-accent-800: #8a3a19;
  --color-accent-900: #5e260f;

  /* Warm neutrals (supplement Tailwind's gray) */
  --color-warm-50: #fafaf8;
  --color-warm-100: #f4f2ee;
  --color-warm-200: #e4dfd8;
  --color-warm-300: #c9c2b8;
  --color-warm-400: #9e9590;
  --color-warm-500: #6e6760;
  --color-warm-600: #4e4840;
  --color-warm-700: #332d28;
  --color-warm-800: #1c1814;
  --color-warm-900: #0e0b09;
}
```

---

## Spacing & Layout

Uses Tailwind's default 4px base grid. Custom additions:

| Token         | Value        | Use                          |
| ------------- | ------------ | ---------------------------- |
| `gap-section` | 64px / 4rem  | Between page sections        |
| `gap-content` | 32px / 2rem  | Between major content blocks |
| `gap-element` | 16px / 1rem  | Between related elements     |
| `gap-tight`   | 8px / 0.5rem | Within components            |

**Container widths:**

- Default max width: `max-w-3xl` (768px) — search form, results
- Wide content: `max-w-5xl` (1024px) — landing page sections
- Full layout: `max-w-7xl` (1280px) — with side padding

**Border radius scale:**

- `rounded-sm` (4px) — tags, badges, chips
- `rounded-lg` (8px) — inputs, small buttons
- `rounded-xl` (12px) — cards, panels
- `rounded-2xl` (16px) — feature cards, large panels
- `rounded-full` — pill badges, avatar circles

---

## Component Patterns

### Buttons

| Variant     | Background   | Text        | Hover         | Use                          |
| ----------- | ------------ | ----------- | ------------- | ---------------------------- |
| Primary     | `accent-500` | white       | `accent-600`  | Main CTA (Book, Submit, Try) |
| Secondary   | `brand-600`  | white       | `brand-700`   | Important secondary actions  |
| Ghost       | transparent  | `brand-600` | `brand-light` | Nav links, tertiary actions  |
| Destructive | `red-600`    | white       | `red-700`     | Delete, cancel subscription  |

Button height: `h-11` (44px min) for touch compliance.

### Cards

```
bg-surface border border-warm-200 rounded-xl
shadow-sm (light) / shadow-none (dark — use border instead)
p-5 or p-6
```

### Form Inputs

```
bg-surface border border-warm-200 rounded-lg h-11
focus:border-brand-600 focus:ring-2 focus:ring-brand-600/20
placeholder:text-warm-400
```

### Navigation

- Background: `bg-surface border-b border-warm-200`
- Logo link: `font-heading font-semibold text-warm-800`
- Nav links: `text-sm text-warm-500 hover:text-warm-800 transition-colors`
- Active link: `text-brand-600 font-medium`
- Height: `h-14`

### Score Badges

Score circles on flight cards use the semantic signal colors. Size: `w-10 h-10 rounded-full`.

---

## Iconography

- **Library:** Heroicons (already used via inline SVG in views)
- **Style:** Outline (24px) for navigation and UI; Mini (20px) for inline/dense contexts
- **Color:** Inherits from parent `text-*` class — never hardcode icon colors
- **Stroke width:** 1.5px (Heroicons default) — do not mix with other icon sets
- **No emojis as icons** — ever

---

## Animation & Transitions

| Type       | Duration | Easing        | Use                             |
| ---------- | -------- | ------------- | ------------------------------- |
| Micro      | 150ms    | `ease-out`    | Hover states, focus rings       |
| Transition | 200ms    | `ease-in-out` | Color changes, opacity          |
| Reveal     | 300ms    | `ease-out`    | Cards appearing, panels opening |
| Loading    | loop     | `ease-in-out` | Spinner, skeleton pulse         |

**Rule:** All interactive elements get `transition-colors duration-150` at minimum.
**Rule:** Respect `prefers-reduced-motion` — never animate structural layout changes.

---

## Dark Mode Strategy

Dark mode is supported but **not the primary design surface** — light mode is default.

**Implementation:** Toggle via `data-theme="dark"` on `<html>` or OS preference via `@media (prefers-color-scheme: dark)`.

**Key rules:**

- Dark mode uses desaturated/lighter tonal variants of brand colors — not inverted
- Borders replace shadows in dark mode (shadows are invisible on dark bg)
- Test contrast independently for each mode — light mode passing does not imply dark mode passes

---

## Accessibility Standards

- Body text contrast: minimum 4.5:1 (WCAG AA)
- Large text / UI components: minimum 3:1
- Focus rings: `ring-2 ring-brand-600/50` — always visible, never removed
- Color is never the sole indicator — always pair with text or icon
- Minimum touch target: 44×44px (`h-11 min-w-11`)
- All interactive elements: `cursor-pointer`

---

## Files & Locations

| File                                        | Purpose                                            |
| ------------------------------------------- | -------------------------------------------------- |
| `docs/design-system.md`                     | This document — brand rules and token reference    |
| `app/assets/tailwind/application.css`       | Tailwind v4 `@theme` token definitions             |
| `app/views/layouts/application.html.erb`    | Google Fonts import, nav markup, body classes      |
| `public/logo.svg`                           | Primary brand mark (SVG)                           |
| `app/presenters/ranked_flight_presenter.rb` | Semantic signal colors for flight scores           |
| `app/presenters/insights_presenter.rb`      | Semantic signal colors for booking recommendations |

---

## What This System Does NOT Cover

- Domain logic, scoring weights, or business rules → see `docs/domain/`
- Product behavior, insight definitions → see `docs/PRODUCT_GUIDE.md`
- Architecture rules → see `CLAUDE.md` and `.cursor/rules/`
