# Pull Request - AL Performance Review

> Use this template for every PR that touches AL code on a Business Central extension. Tick every box honestly. Where a check does not apply, write "N/A" with a one-line reason.

## Type of Change

- [ ] New feature
- [ ] Bug fix
- [ ] Refactor / cleanup
- [ ] Performance improvement
- [ ] Other (describe):

## Performance Impact

- [ ] None expected (purely additive, no hot path touched)
- [ ] Improves performance (describe what and how much)
- [ ] Potential negative impact (describe and explain mitigation)

If "Potential" is ticked, attach a `.alcpuprofile` from before and after, or explain why a profile is not feasible.

## AL Performance Checklist

### Data access

- [ ] Correct data access method used (`Get` for PK, `IsEmpty` to check existence, `FindFirst` for indexed single record). `FindSet` only used when truly necessary.
- [ ] Filters applied **before** the loop, not inside it.
- [ ] `SetCurrentKey` set explicitly when a non-primary index is required.
- [ ] Only required fields retrieved (avoid wide reads if narrow will do).

### Loops

- [ ] `ModifyAll` / `DeleteAll` used where bulk operations apply (no record-by-record update loops).
- [ ] Temporary tables used for intermediate processing, sorting, or heavy looping.
- [ ] Queries used in place of nested loops where the join is non-trivial.

### Event subscribers

- [ ] Subscribers reviewed for performance cost.
- [ ] Subscribers exit early when conditions are not met (temp records, wrong type, missing data).
- [ ] No unnecessary DB reads or writes inside subscribers.
- [ ] `SkipOnMissingLicense` / `SkipOnMissingPermission` set deliberately (see the project AL standards).

### Design and scalability

- [ ] No assumptions about small data sets in production.
- [ ] No auto-increment fields used as primary keys.
- [ ] Design scales as data volume and user concurrency grow.

## Testing Performed

- [ ] Unit tests added or updated for the change
- [ ] Manual smoke test of the affected flow
- [ ] Performance comparison (before / after timings if applicable)

## Performance Profiler

- [ ] Performance Profiler results attached (`.alcpuprofile` file). Required when "Potential" performance impact is ticked.
- [ ] N/A: no performance-sensitive code touched.

## Reviewer Notes

What the reviewer should focus on. Anything tricky, anything that broke during development, anything intentionally out of scope.

## Final Checklist

- [ ] Branch name follows `wip/<masterVersion>/<workItemId>-<FeatureDescription>`
- [ ] At least one commit references the work item with `#<id>`
- [ ] PR description above is filled in honestly
- [ ] No `ODataKeyFields` introduced in any API query (project house rule)
- [ ] No em dashes in any user-facing strings, comments, or commit messages

---

Adapted from the project AL performance review standards.
