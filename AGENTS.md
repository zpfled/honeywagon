# AGENTS.md

This document defines how AI agents and developers should reason about, design, and extend the Sit & Git operations application.

This app is an **operational system of record** for a real-world logistics business.  
Correctness, auditability, and operational trust matter more than cleverness.

---

## 1. User Profile

- You are a former software engineer who now teaches middle school and runs **Sit & Git**, a portable toilet rental company.
- You are comfortable with technology (including Rails), but are out of practice and time-constrained.
- You prefer:
  - concrete examples
  - screenshots or working demos
  - short, outcome-focused explanations
- You will be using this app daily during peak season under stress.

### Primary Goals
- Prevent overbooking through accurate inventory availability.
- Plan and execute efficient daily routes.
- Maintain **legally compliant service logs** suitable for Wisconsin DNR reporting (NR 113).
- Maintain a reliable operational record of orders, services, and disposals.

### Secondary / Future Goals
- Smart pricing
- Driver-facing mobile experience
- Customer-facing quote and request flow

### Constraints
- **Inventory accuracy and routing correctness are mandatory from day one.**
- Beta as soon as possible.
- Fully production-ready by **April 2026** (start of busy season).

---

## 2. Communication Rules

- Prefer **plain language** and real-world framing.
- Use technical terms only when they add clarity.
- Assume the reader is a Rails engineer who has been out of practice for a couple of years.
- When presenting options:
  - explain tradeoffs
  - give a clear recommendation
  - avoid unnecessary depth unless requested

---

## 3. Decision-Making Authority

- Agents may recommend any technical approach (languages, frameworks, libraries, architecture).
- All non-trivial technical decisions **must be presented as a plan and approved** before implementation.
- Choose boring, reliable, well-supported technologies.
- Optimize for:
  - maintainability
  - clarity
  - operational correctness
- Document **technical** decisions in `TECHNICAL.md`.

Operational rules and invariants belong in this file.

---

## 4. When to Involve the User

Always involve the user when decisions affect:
- operational correctness
- compliance behavior
- workflow friction
- peak-season reliability

Examples:
- enforcing vs warning on invalid states
- adding automation that writes to external systems
- changing routing or inventory semantics
- introducing blocking behavior

---

## 5. Operational Invariants (NON-NEGOTIABLE)

These rules must always hold.  
If a proposed change violates any of these, stop and ask for approval.

### Inventory & Availability
- Inventory is tracked **by individual units** (with unit types), with availability summarized by type/count as needed.
- Availability is still calculated at the unit-type level using date overlap, regardless of unit assignment.
- Availability is determined **only by date overlap**, not booking order.
- A unit type is unavailable from delivery date through pickup date (inclusive).
- Availability blockers include:
  - active rentals (date ranges)
  - out-of-service windows (date ranges)
- A configurable **safety buffer** per unit type reduces availability before overbooking warnings appear.
- Overbooking is allowed **with warnings**, never silently.

### Routing
- Routing is a **single mixed-task system**:
  - deliveries
  - services
  - pickups
- Deliveries have:
  - a hard “not later than” constraint
  - flexible ordering (can be moved earlier, never later)
- When routes fail mid-day, **deliveries take priority** over services and pickups.

### Compliance (Wisconsin NR 113)
- Service completion and disposal logging are **decoupled in time**.
- Compliance is achieved through **eventual completeness**, not atomic actions.
- Disposal events may cover multiple service events.
- Historical data must never be silently modified or auto-corrected.
- Late or back-dated entries must surface **compliance exceptions**.

### Failure Handling
- Problems are surfaced as **“Attention Needed”**, without assigning blame.
- Visibility ≠ responsibility.
- Exceptions must escalate visually over time but never block daily operations.

---

## 6. Source-of-Truth Rules

This app is the source of truth for:
- orders
- scheduling
- routing
- service events
- inventory availability

### External Systems
- **QuickBooks**
  - Source of truth for billing and accounting.
  - Remains part of the workflow.
  - Conflicts must be detected and surfaced for manual resolution.
  - Writes are allowed only after explicit confirmation per record (before April 2026).

- **Google Calendar**
  - Removed from the operational workflow.
  - External changes are ignored entirely.

### General Integration Rule
- All new integrations start **read-only**.
- Write access must be explicitly approved and documented.
- No silent bidirectional syncs.

---

## 7. Engineering Standards

- Write clean, maintainable, boring code.
- Favor clarity over cleverness.
- Controllers:
  - load resources
  - call services
  - render views
  - **no business logic**
- Models:
  - validations
  - associations
  - minimal domain behavior
- Services:
  - business rules and workflows
  - idempotent where possible
- Views:
  - markup only
  - no queries or business logic
- Presenters:
  - formatting and aggregation
  - accept preloaded data
- Helpers:
  - cross-domain formatting only (dates, money)
- Include automated tests for all core logic.
- Handle errors gracefully with user-friendly messages.

---

## 8. Quality Assurance

- Never present broken features.
- If something cannot be fully tested automatically, explain why.
- Prefer warnings and visibility over hard blocks.
- Automate checks before deploying to production.

---

## 9. Compliance Logging Requirements (NR 113)

At minimum, each service event must support recording:
- service location (address or alternate identifier)
- date and time of service
- system type (portable restroom)
- description of waste pumped
- gallons collected
- disposal location
- disposal date and time
- operator identity
- certification metadata

Electronic records are allowed and must be retained for **5 years**.

---

## 10. Exception & Resolution Tracking

- All exceptions must be classified (e.g., data, workflow, integration).
- Resolution tracking must record:
  - category
  - resolution type
  - timestamp
  - actor (owner, driver, system)
- Narrative postmortems are optional.
- Structured data is preferred to enable pattern analysis.

---

## 11. Showing Progress

- Prefer working demos over descriptions.
- Describe progress in **user-outcome terms**:
  - “You can now schedule deliveries without overbooking”
  - “Compliance gaps are visible on the dashboard”
- Screenshots or short recordings are encouraged.
- Celebrate meaningful milestones.

---

## 12. Explicit Non-Goals (Before April 2026)
- No automated pricing engine
- No customer self-service scheduling
- No hard enforcement that blocks daily operations
- No automatic bidirectional sync with external systems
