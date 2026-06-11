---
bc-version: [all]
domain: integration
keywords: [idempotency, deduplication, idempotency-key, inbound, replay, in-progress, unique-key]
technologies: [al]
countries: [w1]
application-area: [all]
---

# Deduplicate inbound messages with an idempotency check

## Description

Duplicate inbound messages are a guarantee, not an edge case. A source system re-fetches and resends after a restart, a webhook platform fires a retry because it did not see your acknowledgement in time, a poll window overlaps a previous one, a load balancer replays a request. Every one of these delivers a message you have already seen, and the source genuinely believes it is doing the right thing by retrying. The receiver, not the sender, is responsible for recognising the repeat, because only the receiver knows what it has already processed.

The mechanism that makes recognition possible is the Idempotency Key: a stable value the caller controls. Before staging an inbound message, look it up by that key. If a matching message is already Completed, return its stored response and do nothing else, because the work is already done. If a matching message is In Progress, wait or reject rather than start a second concurrent run against the same key. Only when there is no match do you stage a new message and process it. Skip this check and a slow or duplicating external system turns every replay into real work: duplicate sales orders, double postings, duplicate outbound side effects that ripple to yet more systems.

## Best Practice

Deduplicate on the `Idempotency Key`, the stable value the caller controls, and back it with a unique key so the lookup is a single indexed read and a concurrent duplicate insert fails at the database rather than racing through. Never deduplicate on the internal Message ID: that GUID is generated fresh on every insert, so it never matches a replay and gives you the illusion of a dedup check that can never fire. On a Completed hit return the stored response so the caller sees the same answer it would have seen the first time; on an In Progress hit reject or back off so two runs do not process the same key at once; only on no hit do you insert and process. See `al-deduplicate-inbound-messages-with-an-idempotency-check.good.al`.

The trade-off is one indexed read on the ingest path, which is cheap, and a unique key that will reject a genuine duplicate insert, which is the point. Pair this with outbound idempotency keys (see `al-send-an-idempotency-key-on-every-outbound-call.md`) so the same flow is protected against duplicates on the way out as well as on the way in.

## Anti Pattern

An inbound handler that inserts a new Integration Message on every call without first checking for an existing one, or that deduplicates on the internal Message ID instead of the Idempotency Key. The detection signal: an `Insert` of an inbound message with no prior `SetRange`/`Get` on `"Idempotency Key"`, a `CreateGuid()` used as the dedup key, or a dedup lookup keyed on `Message ID`. The consequence is that a retried or re-fetched delivery is processed as a brand-new message, so a duplicating source produces duplicate documents and double-applied side effects, and the volume scales with how aggressively the source retries. The fix is a lookup on `Idempotency Key` before any insert, backed by a unique key. See `al-deduplicate-inbound-messages-with-an-idempotency-check.bad.al`.

## See also

- `al-send-an-idempotency-key-on-every-outbound-call.md`
- `al-use-a-framing-record-for-inbound-polling.md`
- `al-stage-every-integration-message.md`
