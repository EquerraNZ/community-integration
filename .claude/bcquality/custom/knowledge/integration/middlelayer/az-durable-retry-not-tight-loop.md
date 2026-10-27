---
bc-version: [all]
domain: integration
keywords: [azure, durable-functions, scheduled-retry, timer, backoff, tight-loop, middle-layer]
technologies: [js]
countries: [w1]
application-area: [all]
---

# Schedule long retries with a durable timer, not a tight loop

## Description

Some retries are not seconds apart but hours: a downstream system is down for maintenance, a batch window opens once a night, a partner rate limit resets tomorrow. The wrong way to wait is to keep an execution alive, a Function spinning in a sleep-and-retry loop, a Logic App `Until` with a long delay, or a BC Job Queue entry re-running on a tight schedule and burning a slot each time. Each of these holds a resource open (or wakes constantly) just to pass time, loses its place if the host recycles, and does not survive a deployment. The right primitive is a durable timer: a Durable Function (or a Logic App that re-triggers on a scheduled callback) that parks the work, releases its compute, and is woken by the platform at the scheduled time. Between attempts it costs nothing and holds no thread.

Durable retries must also keep the idempotency key stable across the long gap (see `az-forward-idempotency-key.md`): a retry that lands tomorrow has to look, to the receiver, like the same request as today's attempt.

## Best Practice

Use a Durable Function orchestrator with `createTimer` for the backoff between attempts, so the orchestration sleeps without consuming a worker and resumes exactly where it left off, replay-safe across host restarts. Keep the idempotency key on the orchestration input so every scheduled attempt carries the same value. Bound the total attempts and hand off to the dead-letter path when they are spent. See `az-durable-retry-not-tight-loop.good.js`.

## Anti Pattern

A Function that calls the dependency, and on failure `await`s a long sleep and calls again inside the same invocation, or a Logic App `Until` with a multi-hour `Wait`, or a BC Job Queue entry polling every few minutes to pass a multi-hour wait. The detection signal: a long `setTimeout`/`sleep`/`Wait` on a live execution path used to defer a retry, rather than a durable timer or a scheduled trigger. The consequence is compute (and in BC a Job Queue slot) held open to do nothing, retry state lost on recycle, and a wait that silently resets on every deployment. See `az-durable-retry-not-tight-loop.bad.js`.

## See also

- `al-accept-async-work-instead-of-synchronous-wait-loops.md`
- `az-retry-in-plane.md`
- `az-202-status-poll.md`
- `az-forward-idempotency-key.md`
