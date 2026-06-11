# Feature Spec: Message list and resolution

- **Feature id:** 002-message-list-and-resolution
- **Roadmap item:** specs/roadmap.md item 2
- **Status:** spec

## Problem

The core stages and classifies messages but gives operations nowhere to see or act
on them. A failed message that needs a human must be visible, its payload and error
readable, and its re-run safe. This feature is the operational surface: a list, a
resolution card, and the three manual actions, mirroring the E-Document shape so the
audit story is familiar.

## Users and roles

- **Operations staff** monitor the message queue and resolve failures.
- **Integration administrator** investigates classes of failure.

## Scope

- An **Integration Message List**: every message, filterable by status, direction,
  type, and correlation id, with the failed ones easy to find.
- An **Integration Message Card** (the resolution page): the message detail, the
  classified error, and the request payload kept **editable while Failed** so ops
  can correct it before re-running.
- Three **manual actions** over a Failed message, each preserving the Message ID so
  the re-run keeps the idempotency guarantee:
  - **Resolve**: re-queue the same message (after a payload fix) for the dispatcher.
  - **Confirm by Exception**: accept the message as handled with no retry, keeping
    the audit record.
  - **Reassign**: re-resolve the handler from the (possibly corrected) Type and
    re-queue, for a message staged against the wrong type.
- Permission set entries for the new objects.

## Out of scope

- Bulk resolution across many messages (one at a time for this build).
- A retention / archive policy for Resolved messages (parked, open question 4).
- Any change to how messages are staged or dispatched (feature 001 owns that).

## User flow

1. Ops opens the Integration Message List, filters to Failed, and opens one.
2. The card shows the error class, the error text, and the request payload.
3. For a data error, ops corrects the payload on the card and chooses Resolve. The
   message returns to New with the same Message ID; the dispatcher re-runs it.
4. For a message that should not be retried (a duplicate handled elsewhere, a
   business decision), ops chooses Confirm by Exception. The message is marked
   Resolved with the audit trail intact and no re-run.
5. For a message staged against the wrong type, ops corrects the Type Code and
   chooses Reassign; it re-queues against the corrected handler.

## Acceptance criteria

- [ ] Given a Failed message, when ops chooses Resolve, then the message Status
      returns to New, the error is cleared, and the Message ID is unchanged.
- [ ] Given a Failed message, when ops chooses Confirm by Exception, then the
      message Status becomes Resolved, the Retry Count is not incremented, and the
      error text is preserved in the audit record.
- [ ] Given a Failed message whose Type Code is corrected on the card, when ops
      chooses Reassign, then the message Type is re-resolved from the corrected code
      and the Status returns to New.
- [ ] Given a Failed message, when ops edits the request payload on the card, then
      the new payload is persisted to the message and used on the next run.
- [ ] Given a message that is not Failed, then the three resolution actions and the
      payload/type editing are disabled.
- [ ] Given any object this feature defines, then it is in the Integration
      Foundation permission set.

## Data and rules

- A re-run **reuses the existing Message ID**; no action mints a new GUID. This is
  what keeps a human-driven retry as duplicate-safe as an automated one.
- The request payload and the Type Code are editable **only** while Status =
  Failed; every other field and state is read-only on the card.
- Confirm by Exception preserves the Error Message for the audit trail; it does not
  blank it.

## Telemetry and audit

Each manual action emits telemetry through the feature 001 telemetry codeunit:
resolve re-queued (INT-0008), confirmed by exception (INT-0009), reassigned
(INT-0010), each carrying the correlation id and message id, no payload.

## Open questions

None blocking. Retention policy stays parked (open question 4).
