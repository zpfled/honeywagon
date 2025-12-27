# Dumpr

Dumpr is the internal operations platform for a portable sanitation company.  
It manages inventory, pricing, weather-aware routes, and field reporting using real unit assignments so overbooking isn’t possible.  
The product is unapologetically opinionated toward how portable toilet operators work in the real world.

---

## Code Hardening Plan

- See [`CODE_HARDENING_PLAN.md`](CODE_HARDENING_PLAN.md) for the step-by-step refactor roadmap.

## Highlights

- ✅ **Inventory truth** — every order reserves physical units; availability checks prevent double booking.  
- ✅ **Pricing engine** — rate plans drive rental and service-only pricing; order line items snapshot totals for accounting.  
- ✅ **Route dashboard** — dispatchers see the next two weeks of routes with truck capacity, weather forecasts, and service event badges.  
- ✅ **Field workflow** — drivers/dipatch mark deliveries/recurring service/pickups complete; required events collect reports in-app.  
- ✅ **Dump events** — plan dump stops, reset truck waste loads, and track them in the service log alongside customer work.  
- ✅ **Google Places integration** — order/location forms autocomplete addresses and store lat/lng for routing + weather.  
- ✅ **National Weather Service forecasts** — automatically fetched per company/location to highlight freeze risk and estimated rain.  
- ✅ **Safety net tooling** — RSpec coverage, Brakeman, Bundler Audit, and CI scripts keep the critical scheduling logic honest.

---

## Tech Stack

- Rails 8.1
- Ruby 3.3
- PostgreSQL
- Devise (authentication)
- Pundit (authorization, partial)
- RSpec
- Tailwind CSS (via tailwindcss-rails 4, semantic HTML-first UI)

---

## Core Concepts

### Unit Types
Categories of rentable assets:
- Standard units
- ADA units
- Handwash stations

Each UnitType maintains its own serial counter and prefix.

### Units
Physical assets that get assigned to orders.
- Globally unique serials
- Concurrency-safe serial generation
- Lifecycle statuses (available, maintenance, etc.)

### Locations
Any place a truck visits:
- Job sites
- Customer properties
- Dump sites (flagged in the same table)

There is intentionally no separate Address model.

---

## Orders & Rentals

### Orders
An order represents a rental window.
- start_date / end_date
- customer and location
- assigned units
- pricing totals

Orders assign actual units, not abstract quantities.

### Availability Enforcement
Units cannot be double-booked.

A unit is unavailable if it is assigned to another order with overlapping dates:

existing.start_date <= requested.end_date  
AND existing.end_date >= requested.start_date

This logic is enforced centrally and tested.

---

## Pricing Model

Pricing is fully data-driven.

### Rate Plans
- unit_type
- service schedule (weekly, biweekly, event)
- billing period (monthly, per_event)
- price
- active windows

---

## Integrations

- **Google Maps Places / Geocoding**  
  Address fields in the order/location forms use Google Places Autocomplete, and locations are geocoded automatically for route planning.  
  Configure via `Rails.application.credentials.google_maps.api_key` or `GOOGLE_MAPS_API_KEY` (restrict the key to trusted domains/IPs).

### Order Line Items
Orders snapshot pricing into line items at build time:
- quantity
- unit price
- subtotal
- billing metadata

Historical pricing remains stable even if rate plans change later.

---

## Order Builder

All rental logic lives in a service object:

Orders::Builder

Responsibilities:
- Validate dates
- Enforce availability
- Assign real units
- Build order line items
- Calculate totals

Errors are added to order.errors[:base].  
The builder does not rely on order.valid?.

---

## Service Events, Routes & Field Work

### Auto-generated lifecycle
- Scheduling an order calls `Orders::ServiceEventGenerator` which rebuilds the delivery, recurring service, pickup, and dump prep events.
- Events use `ServiceEventType` metadata (requires report? custom fields?) so we can add new categories without rewriting logic.
- Weekly/biweekly plans inject midpoint service visits; auto-generated rows are safe to regenerate in-place.

### Dispatch dashboard
- The dashboard shows the next **two weeks** of routes, grouped by truck, with alternating rows, capacity icons, and weather freeze warnings.
- A compact overview card keeps YTD revenue and per-unit-type availability visible without pushing the routes table below the fold.
- “New route” lives in a collapsible drawer, keeping focus on upcoming work while still allowing fast additions.

### Field actions
- Deliveries can move earlier but never later; pickups can move later (truck delays happen) but not earlier.  
- Drivers mark events complete from the route view; service events that require data launch the reporting form, all inline.  
- Dump events are schedulable and show up in the route just like a customer stop, resetting each truck’s waste tally when completed.

### Reporting & compliance
- Service and pickup events capture `ServiceEventReport` JSON (estimated gallons, units serviced, etc.).  
- Reports both persist the measurements and mark the event complete in the same transaction.  
- `/service_event_reports` provides a chronological log for accounting/compliance export.

---

## Everyday Usage

1. **Create customers & locations** (new customer modal → add location with Google autocomplete).  
2. **Create an order**  
   - Select customer/location  
   - Enter start/end dates (availability sidebar automatically shows per-unit-type counts)  
   - Add rental or service-only line items (rate-plan driven pricing)  
3. **Schedule the order** – this generates delivery/service/pickup events.  
4. **Review the dashboard** – dispatchers see the upcoming routes, weather risks, and unit workloads.  
5. **Adjust routes** – postpone/advance events as needed, schedule dump stops, and keep an eye on truck trailer capacity.  
6. **Complete events** – deliveries flip the order to `active`; services/pickups prompt drivers for any required report fields.  
7. **Audit** – Service log and inventory overview provide quick status snapshots for management.

---

## Development Setup

1. `bin/setup` – installs gems, prepares the DB, and clears tmp/logs.
2. `bin/rails db:seed` – loads the opinionated demo data so the dashboard has upcoming events and service history to show.
3. `bin/dev` – runs the Rails server and Tailwind 4 watcher via `Procfile.dev`. (If you prefer, run `bin/rails server` and `bin/rails tailwindcss:watch` in separate shells.)

---

## Testing

- `bundle exec rspec` – primary test suite (models, services, requests, presenters).
- `bin/ci` – runs `bin/setup --skip-server`, RuboCop, Bundler Audit, Importmap audit, Brakeman, Rails test + system test tasks, and a seed replant to prove demo data still loads.

---

## Project Status

- Core rental logic: complete
- Inventory overbooking prevention: complete
- Pricing engine: complete for standard units
- Tailwind UI: functional, intentionally minimal
- Service event dashboard + reporting: shipped
- Service log / compliance export: shipped
- Driver- or route-specific workflow: pending (current UI is global for dispatch)

---

## Scope & Intent

Dumpr is built first for real operational use.  
Generalization is possible, but correctness for portable sanitation comes first.

If you’re reading this as a collaborator:
- Expect strong domain opinions
- Expect boring UI and serious data integrity
- Expect tests around the hard parts
