# Capacity Routing v2 Plan

This plan defines the next-generation capacity-aware routing approach. It is a
living implementation document. Major portions are now implemented, while some
sections remain future work.

## Goals
- Minimize total miles driven (primary success metric).
- Respect delivery/pickup constraints.
- Handle capacity limits for waste, clean water, and trailer spots.
- Support multiple routes per day with home base as start/end.
- Allow services to move earlier within a configurable horizon.
- Auto-split large deliveries when required by capacity.

## Decisions (Confirmed)
- Deliveries/pickups retain existing constraints.
- Services can move earlier within the routing horizon.
- Auto-split deliveries without manual confirmation.
- Use a review/accept step before new routes replace existing ones.
- Use straight-line (lat/lng) distances for clustering/ordering.
- Dump when waste reaches 90% capacity (configurable).
- Prefer truck/trailer by preference rank; when ranks are tied or missing,
  truck selection currently falls back to lower waste capacity.
- Remote locations are prioritized, not forced into their own route.
- Rerun routing on every new order scheduled.

## Phase 0 - Documentation
- Document algorithm choices and configuration in `TECHNICAL.md`.

## Phase 1 - Configuration + Data
- Add company settings:
  - `routing_horizon_days` (default: 3)
  - `dump_threshold_percent` (default: 90)
- Add equipment preference rank for trucks and trailers.
- Add a `location_distances` table:
  - `from_location_id`, `to_location_id`, `distance_km`, `computed_at`
  - Unique index on `(from_location_id, to_location_id)`
  - Store both directions for fast lookup.
- Background job updates distances when a location changes.

## Phase 2 - Auto-Splitting Deliveries
- Split large deliveries into multiple delivery events when trailer capacity
  requires it.
- Split pickups into multiple pickup events when trailer capacity requires it.
- Services remain intact (not split by this phase).
- Link split events to the parent order for auditability.

## Phase 3 - Route Builder (Cluster First, Then Order)
- Build a candidate pool within `routing_horizon_days`.
- Cluster by candidate-to-candidate proximity using straight-line distance
  and connected-neighbor grouping (not distance bands from home base).
- For each cluster, build routes:
  - Start/end at home base.
  - Greedy next-stop ordering with weighted scoring:
    - distance from previous stop
    - due date urgency
    - remote priority
    - capacity impact
  - Insert dump/refill when threshold would be exceeded.
  - Insert trailer reload at home base when capacity exceeded.
  - Aim to place the last stop near dump/home when required.
  - Each home base visit ends a route.

## Phase 4 - Equipment Assignment
- Choose highest-ranked truck first.
- Choose smallest-ranked trailer that satisfies capacity.
- Reserve equipment per route/day.
- When multiple routes share a day, use other available equipment if possible.

## Phase 5 - Review/Accept Workflow
Current state (implemented):
- Capacity routing preview exists as a read-only screen for inspection.
- Route optimization runs per-route from the route page and applies immediately
  when successful (resequence + drive metrics update).
- Routes are marked `optimization_stale` when relevant service events change,
  so operators can see that re-optimization is needed.

Future state (not yet implemented):
- Every schedule change creates a proposed route plan for review.
- Dashboard banner: "New route plan ready • Review".
- Review screen shows:
  - route list + changes (moved stops, dumps/refills, splits)
  - miles, routes, and stop counts
- Actions:
  - Accept all
  - Reject
  - Later
- Allow "lock route" to exclude from automatic changes.

## Phase 6 - Performance Guardrails
- Only compute distances inside horizon + dumps/home.
- Recompute distances only when a location changes.
- Keep logic simple; scale is <100 active orders for now.

## Open Items
- Decide whether to add optional Google routing for final ordering later.
- Define how to visualize split deliveries in the UI.
