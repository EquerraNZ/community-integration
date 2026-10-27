# Technical Design: <Solution Name>

> Constitution document. The how, at the system level, for both halves of the
> solution: which standard Business Central modules and which standard Azure
> services to reuse, and where custom code is genuinely needed on each side.
> Feature plans (`plan.md`) inherit from this. Fill it in, then run
> `/al-spec-init` to review it against the brief.

## Architecture overview

TODO: the shape of the solution and how its parts fit together.

## Standard BC modules to reuse

TODO: the standard Business Central functionality this builds on.

## Custom-code gaps

TODO: only what standard BC cannot do, and why custom code is needed.

## Object ID range

TODO: the assigned AL object ID range for this solution.

## Data model (high level)

TODO: the key tables and relationships.

## Integrations

TODO: inbound, outbound, business events, and external systems.

## Cross-cutting concerns (BC)

TODO: telemetry, permissions, multitenancy, upgrade.

## Azure integration layer: architecture

TODO: the shape of the plane. Which component receives each external message, what
acknowledges the caller, which queue carries it, what stages it into BC, and what
subscribes to BC's outbound events and calls out.

## Standard Azure services to reuse

TODO: the managed services this builds on, and why each one rather than its
alternatives. Retry, dead-lettering, scheduling, and secret storage are configuration
of a managed service, never hand-written code.

## Plane-side custom code

TODO: only the adapters and glue the managed services do not provide, and why.

## Plane cross-cutting concerns

TODO: idempotency and dedup, correlation propagation, retry policy and the
transient/permanent split, dead-letter handling, secrets and managed identity,
observability, and the BC subscription health check.

## Infrastructure, environments, and deployment

TODO: resource groups, naming, what differs between environments, how the plane is
deployed from this repository, and how its identity to BC is granted.

## Open technical questions

TODO: unresolved decisions to settle before or during planning.
