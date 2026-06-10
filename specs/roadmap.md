# Roadmap

> Constitution document. The ordered feature list with status.
>
> Status legend: `todo` | `spec` (spec written) | `planned` (plan + tasks ready)
> | `in-progress` | `done` | `parked`.

## Solution: Integration Foundation

A single, reusable AL extension that gives Business Central a shared staging
record and a set of proven inbound/outbound integration patterns, so consuming
apps add a handler instead of reinventing the plumbing.

## Order of delivery

1. `001-integration-foundation` The framework: one staging record and the six
   patterns built on it, delivered pattern by pattern. Status: `in-progress`
   (all six patterns implemented and verifier-reviewed; pending build on the AL
   toolchain and merge).

   Patterns, in implementation order (each is a milestone inside feature 001;
   summarize after each before moving to the next):

   1. Dispatch foundation: the Integration Message staging record and the engine
      that routes each item to a handler by its Type.
   2. Duplicate detection: idempotent processing keyed on (External Reference,
      Type) with stored-response replay.
   3. Error classification: durable error capture plus a swappable, out-of-band
      classifier (default rule-based, no AI dependency).
   4. Delayed reply: accept now, reply later, correlated by Correlation ID.
   5. Durable staged pipeline: ordered, independently retryable stages with
      parent/child links for spawned work.
   6. Operations and recovery: the manual inspect / retry / resolve / reassign
      experience modelled on standard BC inbound staging.

## Parked / later

- An AI-based error classifier registered through the swappable interface (no
  external AI dependency in the framework itself).
- A companion test app, if the project later decides to ship one.
- Sample connectors demonstrating the framework (kept out of the framework app).

## Done

- (none yet)
