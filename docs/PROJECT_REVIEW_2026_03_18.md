# Flexible Flights — Full Project Review (2026-03-18)

Comprehensive product and codebase review assessing MVP readiness, saleability, information presentation quality, and go-to-market strategy.

---

## 1. Central Idea Assessment

**Verdict: Strong and differentiated.**

"When should I fly?" and "Should I book now or wait?" are questions every flexible traveler asks but no tool answers well. Google Flights shows prices but doesn't synthesize a decision. Skyscanner shows calendars but doesn't score tradeoffs. Hopper predicts prices but doesn't factor comfort or trip fit.

The differentiator is the **intelligence layer** — the product doesn't just show flight options, it produces a scored recommendation with confidence levels, tradeoff explanations, and actionable directives (book_now / consider_booking / wait).

The confidence gating is especially smart. Saying "we don't have enough data to recommend" builds trust, which is critical when selling decisions.

---

## 2. Saleability

**Verdict: Saleable to a passionate niche. Not mass-market on day one — that's fine for MVP.**

**What works:**

- The "wait or book" directive is the kind of thing people would pay to know with confidence
- Price rarity ("this is unusually cheap for this route") creates urgency
- Best time to travel saves hours of manual calendar scanning
- The scoring system (price 45% + comfort 35% + trip fit 20%) maps to how real travelers think

**Risk:**

- Users may not perceive the value until they've used it once and seen a good result — the **first search experience must be flawless**
- The value is strongest for flexible travelers (digital nomads, remote workers, retirees) — not for someone who already knows their dates. Marketing must target that flexibility

**Target niche:** Digital nomads, remote workers, flexible couples/families, retirees. A passionate niche is better than a lukewarm mass market for MVP.

---

## 3. Information Presentation

**Verdict: The bones are strong. The AI copy layer is fully wired. Hierarchy polished (2026-03-24) — insights are now the hero. Frontend design system fully aligned (2026-03-26).**

### What's strong:

- 4 insight cards (wait/book, price rarity, best time, cheapest comfort window) directly answer the user's core questions
- Flight cards with score rings, role tags (Top-rated, Best Price, Best Comfort), and per-flight AI explanations are rich and informative
- Confidence badges (high/medium/low) with appropriate suppression of insights at low confidence
- **Route summary is fully implemented** — `RouteSummaryCopyService` calls Claude Haiku with route data (percentiles, volatility, directive, rarity) and generates a plain-English 2-3 sentence summary rendered in `_results.html.erb`
- **Per-flight AI explanations are batch-generated** via `ExplanationCopyService`, wired through `SearchResultsPresenter` to each `RankedFlightPresenter`
- External search links (Google Flights, Skyscanner) on both insight cards and flight cards reinforce the advisor positioning

### What was polished (2026-03-24):

- ✅ **Recommendation card is now the hero** — full-width, color-coded by directive (`book_now` / `consider_booking` / `wait`), with directive heading, AI route summary in a frosted box, price rarity + confidence tags, and best-time / cheapest-comfort sub-cards all inside the card
- ✅ **Flights demoted to supporting evidence** — appear below the hero under "The flights behind this recommendation"
- ✅ `_insights.html.erb` deleted; content inlined into `_results.html.erb`
- ✅ `SearchResultsPresenter#search_intent_id` added; instance variable coupling removed from partials

### What was polished (2026-03-26):

- ✅ **Accessibility** — `lang` attribute on `<html>`, `aria-hidden` on all decorative SVGs, `aria-live="polite" aria-atomic="true"` wrapper for Turbo Stream result region, `id="main-content"` on `<main>`
- ✅ **Touch targets** — all buttons and submit elements standardized to `h-11` (44px), theme toggle enlarged to `w-11 h-11`
- ✅ **Focus rings** — all inputs and buttons standardized to `focus:ring-2 focus:ring-brand-600/20 focus:border-brand-600`; dark mode override added in `application.css`
- ✅ **Button color consistency** — search submit and failed-state retry use `accent-500` (amber CTA); auth and profile submits use `brand-600` (teal)
- ✅ **External link colors** — all Google Flights / Skyscanner links unified to `text-brand-600 hover:text-brand-700`
- ✅ **Google Fonts performance** — moved from blocking CSS `@import url()` to `<link rel="preconnect">` + `<link rel="stylesheet">` tags in `<head>`
- ✅ **Dark mode card hover** — `dark:hover:bg-dark-surface-raised` added to flight cards (shadow was invisible in dark mode)
- ✅ **Tailwind v4 opacity syntax** — all `bg-opacity-*` and `border-opacity-*` replaced with `/` modifier notation
- ✅ **CCW card colors** — purple (off-brand, no dark mode override) replaced with amber throughout the cheapest comfort window card
- ✅ **Design system documented** — focus ring spec corrected, `prefers-reduced-motion` snippet added, UI feedback colors table, disabled state pattern, breakpoints table, gray/warm token equivalence note

---

## 4. What a Solo Entrepreneur Should Do to Ship

### Must-have for launch:

1. ~~**Payment integration** — Stripe Checkout with search packs. Buy 5 searches for $X, 20 for $Y. No subscriptions, no complexity~~ ✅ **Done (2026-03-20)**
2. ~~**1 free search** — Let users feel the value before paying. This is the conversion funnel~~ ✅ **Done (2026-03-20)**
3. ~~**Landing page** — Explain the value prop before sign-up (keep in Rails)~~ ✅ **Done (2026-03-25)**
4. **Production Amadeus API key** — Integration is working with test endpoint, just needs prod credentials
5. **Error monitoring** — Sentry free tier. Can't fix what you can't see
6. ~~**Basic rate limiting** — Rack::Attack with simple per-user limits to protect Amadeus API quota~~ ✅ **Done (2026-03-25)**
7. **Deploy infrastructure** — Kamal + Hetzner or similar. Rails 8 makes this straightforward

### Nice-to-have but can wait:

- Email notifications ("your search is ready")
- More polished mobile experience
- Analytics (PostHog free tier)
- SEO pages for popular routes

### Skip for MVP:

- Price-drop alerts
- Subscription model
- B2B API
- Multiple providers beyond Amadeus

---

## 5. What's Missing (MVP-Scoped)

| Gap                                                                  | Effort | Priority | Status               |
| -------------------------------------------------------------------- | ------ | -------- | -------------------- |
| ~~Payment system (Stripe Checkout + search packs)~~                  | Medium | Critical | ✅ Done (2026-03-20) |
| ~~Usage metering (credits per user, gate at 0)~~                     | Small  | Critical | ✅ Done (2026-03-20) |
| ~~Landing page (value prop + CTA)~~                                  | Medium | Critical | ✅ Done (2026-03-25) |
| ~~Results page hierarchy polish (insights hero, flights secondary)~~ | Small  | High     | ✅ Done (2026-03-24) |
| Error monitoring (Sentry)                                            | Small  | High     | Not started          |
| ~~Rate limiting (Rack::Attack)~~                                     | Small  | High     | ✅ Done (2026-03-25) |
| Production deploy setup                                              | Medium | High     | Not started          |
| Email "search ready" notification                                    | Small  | Nice     | Not started          |

**What's NOT missing (already built):**

- Full 8-phase domain pipeline (sampling through insights)
- Amadeus integration (production-ready code, needs prod credentials)
- AI-generated route summaries (RouteSummaryCopyService with Claude Haiku)
- AI-generated per-flight explanations (ExplanationCopyService, batch)
- Real-time results via Turbo Streams + Solid Cable
- Auth (Devise)
- i18n (EN + PT-BR)
- 47 spec files with strong domain coverage
- Solid Queue for background jobs
- IDOR protection
- Airport autocomplete (7500+ airports, client-side)
- **Payment system** — Stripe Checkout, credits model, multi-currency (USD + BRL), webhook fulfillment with idempotency, polished pricing UI (2026-03-20)
- **Results page hierarchy** — recommendation card hero, AI route summary inlined, flights as supporting evidence (2026-03-24)
- **Landing page** — Hero with mock result card, trust bar, how-it-works (3 steps), 4 insight cards, pricing section (reuses `CREDIT_PACKS`), FAQ, final CTA strip, footer (2026-03-25)
- **Rate limiting** — Rack::Attack, 4 throttle rules (login/ip, login/email, signup/ip, search/user), Solid Cache backend, 30 request specs (2026-03-25)
- **Frontend design system** — WCAG-compliant focus rings, 44px touch targets, standardized button colors (accent CTA / brand secondary), brand-colored external links, Google Fonts via `<link>` preconnect, dark mode card hover, Tailwind v4 opacity syntax, off-brand purple eliminated, design system doc updated (2026-03-26)

The codebase is genuinely close to shippable. The remaining gap is operational basics (monitoring, deploy).

---

## 6. Landing Page: Rails vs Separate Project

**Verdict: Keep it in Rails. Strongly.**

Reasons:

- Solo dev — one codebase, one deploy, one set of dependencies
- Landing page needs to share auth (sign up to search flow must be seamless)
- Rails with Tailwind can produce a beautiful landing page
- A `PagesController` with a `home` action is trivial
- Turbo/Stimulus setup already handles any needed interactivity
- NextJS would mean: separate deploy, CORS setup, API layer, shared auth tokens, two CI pipelines, two sets of dependencies — all for a landing page

**Recommendation:** `PagesController#home`. Unauthenticated users see landing page. Authenticated users redirect to search. Zero overhead.

---

## 7. Monetization Strategy for MVP

**Recommendation: Search packs + affiliate links**

### Search packs (primary revenue):

- Lowest friction purchase — pay per value unit, no commitment
- Suggested tiers: 1 free search (trial), then packs of 5/15/30
- Users understand what they're buying: "I get 5 smart searches"
- Implementation: Stripe Checkout, credit decrement, done
- Pricing can be adjusted based on learnings

### Affiliate links (supplementary revenue):

- Google Flights and Skyscanner links already exist in flight cards and insight cards
- Adding affiliate tags is near-zero effort
- Natural endpoint: recommendation then click-through then booking then commission
- Aligns incentives: better recommendations = more bookings = more affiliate revenue
- Revenue without extra user friction

### Why NOT the others for MVP:

| Model             | Why not now                                                                        |
| ----------------- | ---------------------------------------------------------------------------------- |
| Freemium          | Already covered by "1 free search" in pack model                                   |
| Price-drop alerts | Requires continuous monitoring infrastructure that doesn't exist. Great v2 feature |
| Subscription      | Can't prove recurring value yet. Need retention data to price correctly            |
| B2B API           | Different sales motion, contracts, SLAs. Later stage                               |

### Pricing instinct:

Start low to get users and data. Something like $2.99/5 searches, $7.99/15, $14.99/30. Can always raise. MVP goal is validating willingness to pay.

---

## Bottom Line

The product has a clear value proposition, a well-architected domain layer, and a frontend that's further along than expected (AI copy, real-time updates, i18n). The payment system is now live — users can purchase search packs via Stripe Checkout, credits are granted atomically via webhook, and the gate prevents searching without credits. The remaining gap to market is the landing page (discovery + conversion) and operational basics (monitoring, rate limiting, deploy).

**Biggest risk:** Making sure the first search result _feels_ worth paying for. ~~The insights need to be the hero of the results page — a clear, definitive recommendation — not buried among flight cards.~~ ✅ Done (2026-03-24) — the recommendation card is now the hero. ~~Remaining risk is the landing page converting first-time visitors before they've seen a result.~~ ✅ Done (2026-03-25) — landing page is live with hero, pricing, and FAQ. ~~Rate limiting is unprotected.~~ ✅ Done (2026-03-25). Remaining risk: operational basics (monitoring, deploy).

---

## 8. Progress Log

| Date       | What shipped                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-03-20 | **Payment system** — Stripe Checkout (hosted), 3 credit packs (5/15/30), multi-currency (USD + BRL), webhook fulfillment with idempotency guard, atomic credit grant via `update_all`, credit gate in `SearchesController`, credit deduction on successful search completion in `SearchRunJob`, polished 3-card pricing UI                                                                                                                                                                                                                                                                                                                                                                      |
| 2026-03-24 | **Results page hierarchy** — Recommendation card is now a full-width hero (directive heading, AI route summary in frosted box, rarity + confidence tags, best-time + cheapest-comfort sub-cards inside card). Flights demoted below under "The flights behind this recommendation". `_insights.html.erb` deleted. `SearchResultsPresenter#search_intent_id` added to remove instance variable coupling from partials.                                                                                                                                                                                                                                                                           |
| 2026-03-25 | **Landing page** — Hero section with mock recommendation card (shows real output format), trust bar (7500+ airports, 1 free search, i18n, no subscription), how-it-works 3-step grid, 4 insight cards (wait/book, price rarity, best time, comfort window), pricing section reusing `CREDIT_PACKS`, FAQ (4 questions), final CTA strip, footer. Unauthenticated users land here; authenticated users redirect to search.                                                                                                                                                                                                                                                                        |
| 2026-03-25 | **Rate limiting** — `rack-attack` gem, 4 throttle rules: login by IP (10/20s), login by email (5/20s), signup by IP (5/60s), search by user (3/60s). Cache backed by Solid Cache (Postgres) in production — no Redis. 30 request specs with per-example `MemoryStore` isolation. Middleware placed after `Warden::Manager` to ensure session is readable.                                                                                                                                                                                                                                                                                                                                       |
| 2026-03-26 | **Frontend design system alignment** — WCAG accessibility fixes (`lang`, `aria-hidden`, `aria-live`/`aria-atomic` for Turbo Stream results); all buttons standardized to 44px touch targets; focus rings unified to `focus:ring-brand-600/20 focus:border-brand-600` with dark mode CSS override; button colors: accent-500 for primary CTA, brand-600 for auth/profile; external links standardized to brand-600; Google Fonts migrated to `<link>` preconnect tags (removed blocking CSS `@import`); dark mode card hover state added; Tailwind v4 opacity `/` modifier syntax applied; purple removed from CCW card (replaced with amber); design system doc updated with 6 documented gaps. |
