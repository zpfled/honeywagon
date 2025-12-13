# Honeywagon

Honeywagon is an internal operations app for a portable toilet rental business.  
It tracks inventory, rentals, pricing, and service work with a focus on real unit assignment and overbooking prevention.

This is not a generic rental app — it models how portable sanitation businesses actually operate.

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

## Service Events & Field Work

Service events now drive the day-to-day workflow.

### Auto-generated lifecycle
- When an order transitions to `scheduled`, `Orders::ServiceEventGenerator` rebuilds delivery, recurring service, and pickup events.
- Events are stored with `ServiceEventType` records so new categories can be added (requires report, custom fields, etc.).
- Weekly and biweekly plans inject midpoint service visits; event rows are marked `auto_generated` so the generator can safely rerun.

### Dispatch dashboard
- The root path lists the next seven days of service events with customer/location context.
- Drivers or dispatchers can mark delivery-only events complete in one click or jump into the reporting flow for events that require data capture.

### Reporting & compliance
- Service and pickup events require a `ServiceEventReport`. The form is prefilled with customer/address + assigned unit counts and captures pump-specific metrics (estimated gallons, units serviced).
- Submitting a report both persists the JSON payload and marks the event completed in a transaction.
- The “Service Log” nav links to `/service_event_reports`, giving accounting/compliance a reverse-chronological audit of submitted reports.

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

Honeywagon is built first for real operational use.  
Generalization is possible, but correctness for portable sanitation comes first.

If you’re reading this as a collaborator:
- Expect strong domain opinions
- Expect boring UI and serious data integrity
- Expect tests around the hard parts
