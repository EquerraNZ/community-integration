---
bc-version: [22.0+]
domain: integration
keywords: [integration-message, job-queue, inline-processing, deferred, runtime]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Process integration messages inline by default, defer only when configured

## Problem

A common mistake is to always route staged integration messages through a Job Queue
for processing. This adds unnecessary latency (the Job Queue polling interval) and
complexity (a recurring Job Queue Entry must be configured) when the message can be
processed immediately in the caller's session.

The Job Queue exists for cases where processing must be decoupled from the caller:
long-running work, rate-limited external calls, or batch grouping. For the majority
of inbound messages (parse a JSON payload, create a Sales Order), inline processing
is faster, simpler, and gives the caller an immediate success or failure response.

## Rule

Process an Integration Message at runtime (inline, in the same session) by default.
Only defer to a Job Queue when the message explicitly carries a `Job Queue Category
Code`. The field acts as the opt-in: empty means "process now", populated means
"a Job Queue Entry filtered to this category will pick it up later".

## Rationale

- **Latency.** Inline processing returns the result in the same API call. The caller
  knows immediately whether the message succeeded or failed, with no polling.
- **Simplicity.** No Job Queue Entry configuration is needed for the default path.
  The extension works out of the box.
- **Auditability.** The Integration Message still stages the payload before
  processing, so the audit trail and idempotency contract are preserved regardless of
  whether processing is inline or deferred.
- **Opt-in deferral.** When a handler genuinely needs background processing (calling
  an external system with retry, batching multiple messages, or running under a
  specific user context), the caller or configuration sets the Job Queue Category Code
  and the Job Queue picks it up on schedule.

## When to defer (set a Job Queue Category Code)

- The handler makes outbound HTTP calls that may fail transiently (retry belongs in
  the Job Queue, not inline).
- The handler aggregates multiple messages into a batch before sending.
- The handler must run under a different user or session isolation.
- The processing time exceeds what is acceptable for an API response (~5 seconds).

## When to process inline (leave Job Queue Category Code empty)

- The handler creates or modifies BC records from a parsed payload.
- The handler validates and transforms data with no external dependency.
- The caller expects an immediate result (the API returns the created document number).
