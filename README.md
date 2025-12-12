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
- Minitest + RSpec
- PicoCSS (semantic HTML, minimal JS)

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

## Service Events (In Progress)

Service events track actual work performed:
- pump
- clean
- delivery
- pickup

Events may be associated with:
- a unit
- an order
- a location

The data model exists; UI wiring is ongoing.

---

## Development Setup

bundle install  
bin/rails db:setup  
bin/rails server

---

## Testing

bin/rails test  
bin/rails test test/system/**/*_test.rb

CI runs:
- Brakeman
- Bundler Audit
- RuboCop
- Unit and system tests with Postgres

---

## Project Status

- Core rental logic: complete
- Inventory overbooking prevention: complete
- Pricing engine: complete for standard units
- UI: functional, intentionally minimal
- Service event UI: pending
- Driver workflow: pending

---

## Scope & Intent

Honeywagon is built first for real operational use.  
Generalization is possible, but correctness for portable sanitation comes first.

If you’re reading this as a collaborator:
- Expect strong domain opinions
- Expect boring UI and serious data integrity
- Expect tests around the hard parts
