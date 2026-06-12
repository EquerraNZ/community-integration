# Feature Spec: Permissions and Polish

> The what and why for the extension permission set and final hardening.

- **Feature id:** 006-permissions-and-polish
- **Roadmap item:** #6 in specs/roadmap.md
- **Status:** spec

## Problem

The extension defines tables, pages, and codeunits that BC's permission system
controls. Without a permission set, administrators cannot grant users access to
the extension's functionality. Additionally, the extension needs a clean
entrypoint so administrators can find the setup pages.

## Users and roles

- **BC administrator** assigns the permission set to users.
- **Integration user** (service account or human) needs API page access.
- **Warehouse coordinator / sales staff** need access to list pages and setup.

## Scope

- One permission set granting full RIMD access to all extension tables and
  execute access to all extension codeunits and pages.
- Verify all objects are covered.

## Out of scope

- Granular per-role permission sets (a single "all access" set is sufficient
  for a per-tenant extension at this stage).
- AppSource hardening (feature parked).
- Setup validation wizards (setup pages already validate required fields via
  errors in the processors).

## Acceptance criteria

- [ ] A permission set named "Integration Found." exists with ID 73298480.
- [ ] Every table defined by the extension is in the permission set with RIMD.
- [ ] Every codeunit defined by the extension is in the permission set with X.
- [ ] Every page defined by the extension is in the permission set with X.
- [ ] The permission set compiles without errors.
- [ ] Assigning the permission set to a user grants access to all extension
      functionality without additional permissions.

## Data and rules

- Permission set object ID: 73298480 (Permissions range from tech-design).
- Caption: "Integration Foundation".
- All 4 tables, 10 codeunits, 6 pages.

## Telemetry and audit

No additional telemetry for this feature.

## Open questions

None.
