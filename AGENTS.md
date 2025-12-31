# http://CODEX.md

## Section 1: User Profile
- You are a former software engineer who now teaches middle school and runs Sit & Git, a portable toilet rental company. You are comfortable with technology (including Rails) but out of practice.
- Goal: streamline operations by tracking rentals and inventory to prevent overbooking, plan efficient service routes, track orders, and keep service logs for annual state reporting. Future: smart pricing, driver-facing app, and a customer-facing site for quotes and requests.
- Communication: prefer quick screenshots and short written summaries. A bit of detail is fine.
- Constraints: must-have inventory accuracy and route optimization from day one; expenses per service event are nice-to-have. Beta as soon as possible; fully ready by April 2026 (busy season starts each April).

## Section 2: Communication Rules
- When asking technical questions, provide a succinct critique of possible options and keep things high-level.
- Use technical terms & or code references when necessary.
- Explain things the way you would to a Rails Engineer who has not worked in tech for a couple of years.

## Section 3: Decision-Making Authority
- You may make recommendations for all technical decisions: languages, frameworks, architecture, libraries, hosting, and file structure, and should rigorously defend your recommendations. However, you must get approval for technical decisions.
- Before making changes, present a plan to the user and ask for approval.
- Choose boring, reliable, well-supported technologies and optimize for maintainability and simplicity.
- Document technical decisions separately in http://TECHNICAL.md for developers.

## Section 4: When to Involve the User
- For each option, explain the tradeoff in plain language, how it affects speed, appearance, or ease of use, and provide a clear recommendation the user can accept quickly.
- Examples to ask about: choosing between instant but simpler screens vs richer views that load slightly slower; adding mobile-friendly views that add a day of work.

## Section 5: Engineering Standards
- Write clean, organized, maintainable code with clear structure.
- Include comprehensive automated tests and self-checks.
- Handle errors gracefully with friendly, non-technical messages.
- Validate inputs and follow security best practices.
- Keep version control history clear with meaningful commit messages.
- Separate development and production environments as needed.
- Controllers: load resources, call services, render views; no business logic.
- Views: markup only; no AR queries or conditionals that belong in presenters/services; prefer partials/components.
- Presenters: domain-specific, tested formatting/aggregation; accept preloaded data.
- Helpers: cross-domain formatting (money, dates/times) only; reusable and tested.
- Models: validations, associations, limited domain methods (no display/formatting).
- Services: business rules and workflows; keep them idempotent and testable.

## Section 6: Quality Assurance
- Test everything before showing it to the user; never present broken features. When you can not test it, prompt the user to run rspec
- Explain technical problems before fixing issues.
- Automate checks that run before changes go live.

## Section 7: Showing Progress
- Favor working demos the user can try; use screenshots or short recordings when demos are not practical.
- Describe progress in terms of user experience (“You can now schedule service runs without overbooking”) rather than technical changes.
- Celebrate milestones in plain, outcome-focused language.

## Section 8: Project-Specific Details
- Audience: initial back-office use by the owner; later phases for drivers on the road and customers requesting rentals or quotes.
- Experience: back-office views can be rich and detailed; driver views must be fast and minimal for on-the-road use.
- Core must-haves (day one): perfect inventory tracking to prevent overbooking in 2026; route planning and optimization to minimize drive time and fuel costs.
- Nice-to-haves: per-service expense insight to inform pricing; smart pricing based on costs, job location, and other factors; automated quotes and rental requests on the customer site.
- Compliance: maintain a service log suitable for annual state reporting.
- Timeline: beta immediately; fully ready for the April 2026 busy season.
