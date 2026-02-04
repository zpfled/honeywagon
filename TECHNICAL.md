# http://TECHNICAL.md

## Goals and Timeline
- Near-term: owner-facing web app to prevent overbooking, plan efficient service routes, and keep service logs for state reporting. Expense tracking per service is a nice-to-have for the first release.
- Future phases: driver-facing mobile-first interface and customer-facing quotes/requests with smart pricing.
- Target: beta ASAP; production-ready by April 2026 (busy season).

## Stack and Principles
- Keep existing Ruby on Rails app as the core stack; prioritize stability and maintainability over novelty.
- Postgres as the primary datastore; Redis for background job queues and caching if needed.
- RSpec for tests; Capybara/system specs for UI flows; RuboCop/Standard for linting if already present.
- Background jobs via Sidekiq/ActiveJob for route generation and heavy calculations.
- Map/routing: start with deterministic heuristics and a commodity routing API only if needed; abstract routing behind a service to swap providers later.
- Controllers: load resources, call services, render views; no business logic.
- Views: markup only; no AR queries or conditionals that belong in presenters/services; prefer partials/components.
- Presenters: domain-specific, tested formatting/aggregation; accept preloaded data.
- Helpers: cross-domain formatting (money, dates/times) only; reusable and tested.
- Models: validations, associations, limited domain methods (no display/formatting).
- Services: business rules and workflows; keep them idempotent and testable.

## Architecture and Domain
- Inventory: model units, models/types, availability windows, assignments to orders, and blackout periods for maintenance. Prevent overbooking via database constraints and service-level checks on assignment creation.
- Orders: capture customer, location, requested dates, unit counts/types, and service cadence. Track lifecycle states (quoted, scheduled, active, completed).
- Service runs and stops: represent routes for specific dates, linked to a truck/driver. Stops include location, tasks (delivery, pickup, service), and assigned units/orders.
- Service log: append-only records per service event (who, when, where, what was done, notes, photos optional) to support annual reporting.
- Expenses per service event: record time, distance, consumables, disposal fees, and labor; associate with stops for later pricing analysis.
- Smart pricing (later): pricing engine that considers distance, unit type, duration, service cadence, disposal costs, and congestion. Keep the engine modular and testable.

## Interfaces
- Back office (now): rich, data-dense web UI for scheduling, inventory, and routes; desktop-first with responsive support.
- Driver view (later): mobile-first, minimal UI with offline-tolerant job lists and simple updates (arrived, completed, notes, photos).
- Customer site (later): lightweight quote/request flow with address validation and pricing estimate; queues requests for approval.

## Data and Integrity
- Enforce availability with transactional checks and unique constraints linking units to time windows and orders.
- Geocoding and routing cached to reduce API calls; store canonical coordinates per site.
- Audit trails for status changes and service logs; prefer append-only records for compliance.

## Testing and Quality
- Unit tests for pricing, availability calculations, and routing heuristics.
- Request/system tests for order creation, scheduling, and route generation flows.
- Data integrity tests for overbooking prevention and state transitions.
- CI to run tests and linters on every change; block deploy on failures.

## Deployment and Ops
- Separate development and production environments with environment-based configs.
- Use background worker process alongside web process.
- Centralized logging and metrics for job failures and routing errors.
- Backups for the primary database; verify restore path before launch.

## Risks and Mitigations
- Routing API dependency: start with in-app heuristics; if external API is used, wrap behind a service with graceful fallbacks.
- Overbooking bugs: rely on database constraints plus tests that attempt concurrent bookings.
- Data quality for reporting: enforce required fields on service logs; provide exports for annual filings.

## Decisions
- Company profile updates are orchestrated via `Companies::ProfileUpdater` with dedicated form objects for each workflow branch to keep controllers thin and logic testable.
- Rate plan row aggregation lives in `Companies::RatePlanRowsPresenter` to keep view formatting out of controllers.
- Route optimization inserts auto-generated dump/refill stops via `Routes::Optimization::CapacityPlanner`, using per-unit-type capacity usage fields on `UnitType`.
- Locations can be created with manual latitude/longitude when a street address is unavailable; address fields are optional in that case.
- Company profile includes a dedicated Locations page to edit customer locations (including lat/lng) for routing accuracy.
- Google Calendar push uses per-user OAuth tokens and creates one all-day event per stop on the route date.
