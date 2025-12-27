## Summary

- What changed?
- Why?
- How to verify?

## Display audit (short-lived)

- [ ] Views/partials avoid ActiveRecord calls (no `Model.find/where/order/sum` or implicit queries via helpers).
- [ ] Data for views is fetched in controllers/services/presenters with appropriate `includes`/batching.
- [ ] New/updated presenters have specs for formatting/aggregation edge cases.
- [ ] If display logic stayed inline, a follow-up issue is opened or linked.
