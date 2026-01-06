# Tech Debt

This document tracks known tech debt items and outlines a safe, phased approach to address them.

## ServiceEvent route_date Cleanup

Problem:
- `service_event.route_date` is used for logistics constraints and route scheduling, but it can diverge from `route.route_date`.
- Capacity/route summaries should be tied to the route day, not per-event overrides.
- Divergence creates confusing UI behavior and inconsistent ordering.

Phased approach:
1) Clarify intent and document usage
   - Decide which concerns rely on `service_event.route_date` (logistics validation) vs `route.route_date` (route day).
   - Document the rule in `TECHNICAL.md` and `AGENTS.md` if it affects invariants.

2) Constrain usage
   - Use `route.route_date` for capacity planning, route grouping, and UI ordering.
   - Keep `service_event.route_date` only where delivery/pickup logistics require it.

3) Normalize updates
   - Centralize updates so changes to `route.route_date` propagate consistently.
   - Add a repair/consistency task to align events where safe.

4) Add invariants + tests
   - Enforce `route_date == route.route_date` for service events (non-delivery/pickup).
   - Add specs for delivery/pickup constraints, propagation, and divergence detection.

Tradeoffs:
- Conservative path (recommended): keep the column, limit its usage, enforce consistency.
- Aggressive path: deprecate/remove the column and compute from `route.route_date`; higher migration risk.
