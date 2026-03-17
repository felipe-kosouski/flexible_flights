# Future: Affiliate & Direct Booking Deep Links

**Status:** Not implemented. Documented for future reference.

The current implementation uses generic search redirect links (Google Flights, Skyscanner) pre-filled with route and date data. When ready to monetize through affiliate revenue or provide a tighter booking experience, these are the two paths forward.

---

## Path 1 — Skyscanner Affiliate Program

**What it is:** Skyscanner's affiliate program assigns a partner ID. Adding it to the existing Skyscanner URL earns a commission on bookings made through the link.

**Effort:** Low. The current `FlightSearchUrlBuilder` generates Skyscanner URLs already. Adding affiliate tracking is a one-line change: append `&associateid={YOUR_PARTNER_ID}` to the Skyscanner URL.

**Steps:**

1. Apply at [partners.skyscanner.net](https://partners.skyscanner.net) and receive a partner ID.
2. Add `SKYSCANNER_ASSOCIATE_ID` to Rails credentials.
3. In `FlightSearchUrlBuilder#build_skyscanner_url`, append `&associateid=#{skyscanner_associate_id}` when the env variable is present.
4. Commission is typically paid per click or per booking, depending on agreement tier.

**Note:** Skyscanner search redirect links (what we currently build) qualify for affiliate commission — a full metasearch integration is not required.

---

## Path 2 — Direct Booking Deep Links via Amadeus

**What it is:** Instead of redirecting to a third-party search page, link directly to a specific flight offer. This requires re-querying Amadeus for the same search at click time and using the offer ID to initiate a booking or handoff to an airline booking page.

**Effort:** High. Requires:

- A server-side endpoint that re-queries Amadeus `GET /v2/shopping/flight-offers` with the same params as the original search.
- Price confirmation via `POST /v1/shopping/flight-offers/pricing` (Amadeus requires this before booking).
- Either: redirect to an airline booking page using the confirmed offer, or integrate Amadeus `POST /v1/booking/flight-orders` to initiate the booking transaction directly.

**Why this is deferred:**

- Our flight samples are point-in-time snapshots — offers expire. A direct deep link to a stored offer ID will be stale by the time the user clicks it.
- The Amadeus booking API requires additional credentials, legal agreements, and a payment flow.
- It competes with our positioning as a decision intelligence tool, not a booking platform.

**When to revisit:**

- Once the product has validated that users want to book without leaving the app.
- Once affiliate revenue from Path 1 justifies investing in a native booking flow.

---

## Summary

| Path                   | Effort                       | Revenue model          | When to do it                          |
| ---------------------- | ---------------------------- | ---------------------- | -------------------------------------- |
| Skyscanner affiliate   | Low (1 env var + 1 line)     | Commission per booking | Next monetization milestone            |
| Amadeus direct booking | High (new API, payment flow) | Margin on ticket price | Later stage, after affiliate validated |
