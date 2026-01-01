# Code Hardening Plan

This document outlines an incremental, low-risk path to align the codebase with the requested patterns: skinny controllers, logic in services, formatting via presenters/helpers, reusable view partials, and minimized display logic in models.

## Guiding Principles
- Controllers: load resources, call services, render views; no business logic.
- Views: markup only; no AR queries or conditionals that belong in presenters/services; prefer partials/components.
- Presenters: domain-specific, tested formatting/aggregation; accept preloaded data.
- Helpers: cross-domain formatting (money, dates/times) only; reusable and tested.
- Models: validations, associations, limited domain methods (no display/formatting).
- Services: business rules and workflows; keep them idempotent and testable.

## Workstreams (sequenced, safe to parallelize cautiously)

1) **Baseline & Safety**
- ~Add a short-lived “display audit” section to PR template to force checks for view-query violations.~
- ~Enable logging/notifications for unexpected errors currently rescued (e.g., capacity simulator failures) to surface hidden issues.~
- ~Verify CI covers presenters/helpers; add coverage thresholds for new code paths.~

2) **Controllers Slim-Down**
- Ensure controller actions preload what views need; push aggregation logic into presenters/services.
  - Map each controller action to its view(s) and list what the view reads (models, associations, computed values).
    - Here’s the refactor list based on the view audit and controller notes:
      Checklist to satisfy remaining controller TODOs:
      - routes_controller.rb
        - Move route header/forecast/summary computations into presenters.
        - Ensure stop presenters are built from fully preloaded data (orders, customers, locations, dump sites).
        - Expose stop presenters from Routes::DetailPresenter to remove view logic.
      - orders_controller.rb
        - Preload full OrderPresenter dependencies for show (units→unit_type, rental_line_items→unit_type, service_line_items, service_events→route).
        - Decide if service_event_types should move to a presenter/helper (only if it grows).
      - company_controller.rb
        - Extract update workflow into services/form objects to slim controller.
        - Move rate plan row aggregation/formatting to a presenter if it grows.
      - service_event_reports_controller.rb
        - If prefill/fields logic grows, move into a presenter/service (new/edit actions).
      - orderings_controller.rb
        - Move sequencing/metrics application into a dedicated service (ApplyResult).
      - optimizations_controller.rb
        - Move sequencing/metrics persistence into a dedicated service (ApplyResult).
  - Identify view-side queries/aggregation and decide the right home (presenter/service), plus any missing includes/preloads.
  - Draft a refactor checklist per controller (action → preload changes → logic to move).
  - Implement preloads and move aggregation/formatting to presenters/services; slim controllers accordingly.
  - Update or add presenter/service specs; add request/controller specs where behavior changes.
  - Run relevant specs (or ask you to run rspec if I can’t).
- Introduce service objects for multi-step workflows invoked by controllers (e.g., route creation/update side effects).

3) **Route Index Hardening**
- Add `RouteIndexPresenter` that:
  - Accepts a `relation` of routes (already scoped to company).
  - Preloads trucks/trailers and aggregates service-event counts/estimated gallons via grouped SQL.
  - Exposes plain structs for the view (no AR calls).
- Update `RoutesController#index` to use the presenter and pass presenter rows to the view.
- Update `app/views/routes/index.html.erb` to render via partial `_route_row.html.erb` using presenter data; remove model display methods.
- Tests: presenter unit tests for aggregation and nil/zero cases; view spec for rendering without N+1.

4) **Route Show Hardening**
- Create `StopPresenter` for service events with responsibility for: sequence number, leg distance, fuel cost, overdue flags, move hints, completed state, capacity step formatting, dump site labels, action URLs.
- Extend `Routes::DetailPresenter` to build `stop_presenters` (using preloaded `service_events` and capacity steps) and to guard weather fetch when no geocoded location exists.
- Extract `_stop.html.erb` partial; simplify `show.html.erb` to iterate over presenters and remove inline business logic.
- Extract route-level summary (capacity/waste/drive estimates) into `RoutePresenter` or `RouteSummaryPresenter`.
- Tests: presenter specs covering dump/service/delivery branches, completed/overdue flags, move-enable logic, and capacity step formatting; view/component spec to ensure no AR queries run.

5) **Model Cleanup**
- Remove display/aggregation helpers from `Route` (counts, breakdowns) once views migrate to presenters.
- Keep only domain-centric methods (e.g., sequencing, capacity_summary delegation).
- Add database indexes to support presenter queries as needed.

6) **Helpers Consolidation**
- Move money/date/time formatting into `FormattingHelper` (or narrower helpers) and have presenters call helpers where cross-domain formatting is needed.
- Add helper specs for formatting edge cases (nil, zero, time zones).

7) **Services & Error Handling**
- Narrow rescues in `Routes::DetailPresenter` capacity building; log to error tracker when capacity simulation fails and surface a warning badge via presenter.
- Consider a dedicated service for route ordering operations to keep presenters purely presentational.
- Add unit tests for failure paths (capacity simulator exceptions, missing lat/lng weather fetch).

8) **Performance & Data Strategy**
- Stay with batched query-based aggregation first (RouteIndexPresenter). If profiling shows hotspots:
  - Add counter caches for service event counts.
  - Add materialized columns for estimated gallons with background backfill and reconciliation job.
- Add bullet/N+1 checks in CI for views hitting presenters.

9) **UI Consistency & Reuse**
- Standardize form controls (labels, inputs, buttons) via shared partials or view components; apply to routes forms as first adopters.
- Ensure badges, tables, and capacity indicators use consistent partials/CSS helpers.

10) **Rollout Steps**
- Ship presenters/partials behind small PRs to reduce risk; migrate route views first (high-impact, already identified).
- After each migration, delete redundant model methods and update specs to prevent regressions.
- Monitor logs/metrics for missing includes or unexpected queries; tighten presenter interfaces if needed.

## Issue Seeds (can be split into tickets)
- Add RouteIndexPresenter + `_route_row` partial; migrate index.
- Add StopPresenter + `_stop` partial; migrate show; extend RoutePresenter for summary.
- Tighten Routes::DetailPresenter error handling/logging; guard weather fetch; add tests.
- Clean Route model of display helpers; add missing DB indexes for presenter queries.
- Consolidate formatting helpers (money/dates/times) + specs.
- Add PR template “display audit” checklist; enable Bullet/N+1 check in CI.
