---
bc-version: [all]
domain: integration
keywords: [azure, long-running, 202, status-url, async, callback, durable, parking, middle-layer]
technologies: [js]
countries: [w1]
application-area: [all]
---

# Park long-running work on a 202 plus status URL

## Description

Some external operations do not finish in the lifetime of an HTTP request: a WMS pick that completes when a human scans the last carton, a credit check that takes minutes, a batch that runs overnight. The plane must not hold a synchronous connection open waiting for them. The standard shape is the 202-plus-status-URL pattern: the plane submits the work, the external system returns 202 Accepted with a URL to poll (or accepts a callback), and the plane parks the work and resumes when the result is ready, writing it back to the same BC Integration Message. This mirrors the BC-side rule where a message sits in an Awaiting Reply status (`al-park-long-running-work-on-a-status-url.md`); the plane is what drives the poll or receives the callback on BC's behalf, so BC never blocks and no connection is held open for hours.

A plane that waits synchronously on a long operation ties up a worker, hits the Function or gateway timeout long before the operation completes, and loses the result when it does. Parking is the only pattern that survives the real duration of the work.

## Best Practice

On a 202, read the status URL (or register the callback) and park the orchestration: a Durable Function with `createTimer` to poll at a sensible interval, or a webhook the external system calls on completion. Keep the BC Message ID and idempotency key on the orchestration input so the result is written back to the right staged row and a resubmission stays safe. When the result arrives, patch the Integration Message from Awaiting Reply to Completed (or Failed). Bound the total wait and dead-letter on timeout. See `az-202-status-poll.good.js`.

## Anti Pattern

A plane component that submits the work and then blocks the request thread waiting for completion, a synchronous GET in a loop with no parking, a Logic App `Until` holding the run open for hours, or an `await` on a long operation inside a single Function invocation. The detection signal: a long operation driven to completion on one live execution rather than parked on a durable timer or a callback. The consequence is a worker held open, a timeout before the work finishes, and a lost result. See `az-202-status-poll.bad.js`.

## See also

- `al-park-long-running-work-on-a-status-url.md`
- `az-durable-retry-not-tight-loop.md`
- `az-receiver-acknowledges-fast.md`
