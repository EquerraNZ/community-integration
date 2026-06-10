# Integration Foundation

A reusable Business Central framework for inbound and outbound integrations. It
gives you one shared staging record, the **Integration Message**, and a set of
proven patterns built on it. It is a framework only: it ships no business
scenario, no connector, and no test app. A consuming app adds a handler (and
optionally pipeline stages); it never edits this framework.

Target: Business Central online (SaaS), AL runtime 15.0 (BC 26). Object range
73298400 to 73298499.

## The one record everything is built on

Every pattern reads and writes the **Integration Message** table. The fields that
matter:

| Field | Why it exists |
|---|---|
| Message ID (Guid, PK) | Identity. Never reused, never the duplicate key. |
| Direction | Inbound or outbound. |
| Type | Drives dispatch. An extensible enum that binds to a handler. |
| Status | New, In Progress, Awaiting Reply, Failed, Resolved. The only field the background jobs filter on. |
| External Reference | The stable id from the source system. Half the idempotency key. |
| Correlation ID | One trace id across the whole flow, including a request and its later reply. |
| Parent Message ID | Links spawned work and a reply to its request. |
| Current Stage | The pipeline cursor. None means a single-handler message. |
| Request / Response | The payloads, in and out. |
| Error Message / Error Class / Classified | Durable failure capture, classified out of band. |
| Retry Count | Retry state lives on the record, not in code. |
| Status URL | Where to poll for a long-running reply. |
| Assigned To User ID | Who owns a stuck message during recovery. |

## The patterns

1. **Dispatch foundation.** The `Integration Dispatcher` (a Job Queue codeunit)
   picks up New single-handler messages and routes each to its handler by Type.
   The Type enum `implements IIntegrationHandler`, so dispatch is one line with no
   CASE statement.
2. **Duplicate detection.** `Integration Idempotency Mgt.` keys on (External
   Reference, Type). A duplicate never causes a second side effect; a resolved
   duplicate replays the original stored response, so a retry is indistinguishable
   from the first attempt. The check runs at staging and again as a safety net in
   the dispatcher, so it holds whether a message arrives through the facade or a
   direct API insert.
3. **Error classification.** A handler failure is captured durably by
   `Integration Error Handler` (the message goes Failed with its error text), then
   classified later by `Integration Classifier Job` (a separate Job Queue pass).
   The classifier is resolved from the `Error Classifier Type` enum, so it is
   swappable: register a smarter one (for example an AI classifier) and select it
   in setup, with no change to any caller. The shipped default is rule-based and
   carries no external dependency.
4. **Delayed reply.** `Integration Reply Mgt.` parks a request Awaiting Reply with
   a status URL, then matches a later reply back to it by Correlation ID. Request
   and reply are two rows sharing one Correlation ID.
5. **Durable staged pipeline.** `Integration Pipeline Engine` (a Job Queue
   codeunit) advances a message one stage per cycle. Each stage `implements
   IIntegrationStage` and is dispatched from the `Integration Stage` enum. A failed
   stage is retried on its own; earlier stages are not re-run. Stages spawn child
   work that points back via Parent Message ID.
6. **Operations and recovery.** The **Integration Messages** list and **Integration
   Message Card** let operations inspect, retry, resolve, resolve by exception, and
   reassign messages. The **Integration Activities** cue shows how much is failed,
   in progress, or waiting. Every action keeps an audit trail on the message.

## How dispatch works

```
                       +--------------------------+
 API insert / facade   |   Integration Message    |   Status = New
 StageInbound  ------>  |   (one staging table)    |
                       +------------+-------------+
                                    |
              Job Queue: Integration Dispatcher (single-handler, Current Stage = None)
              Job Queue: Integration Pipeline Engine (Current Stage <> None)
                                    |
                 claim (lock, re-check New) -> In Progress -> Commit
                                    |
                 run inside Codeunit.Run isolation
                  /                                  \
            success                                 error
              |                                       |
   Resolved (or Awaiting Reply           Integration Error Handler:
   if the handler parked it)             capture error durably -> Failed
                                                  |
                                  Integration Classifier Job (out of band)
                                  assigns Error Class
```

The Job Queue claims a message under a lock and re-checks it is still New, so two
runs never process the same row. The handler (or stage) runs inside `Codeunit.Run`,
so a failure rolls back only its own work, never the durable Failed record.

## Plugging in a new integration type and handler

In **your** app, implement the handler and bind it to a new Type value. No change
to this framework.

```al
codeunit 50100 "My Sales Order Handler" implements IIntegrationHandler
{
    procedure Process(var IntegrationMessage: Record "Integration Message")
    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        Payload: Text;
    begin
        Payload := MessageMgt.GetRequestText(IntegrationMessage);
        // ... do the work, then optionally write a response ...
        MessageMgt.SetResponseText(IntegrationMessage, '{"status":"ok"}');
        // Do not set the terminal status; the dispatcher resolves it for you.
        // To park for a later reply, call Integration Reply Mgt.ParkAwaitingReply.
    end;
}

enumextension 50100 "My Integration Types" extends "Integration Type"
{
    value(50100; SalesOrderImport)
    {
        Caption = 'Sales Order Import';
        Implementation = IIntegrationHandler = "My Sales Order Handler";
    }
}
```

Stage a message and the dispatcher routes it:

```al
MessageMgt.StageInbound("Integration Type"::SalesOrderImport, ExternalId, JsonText, IntegrationMessage);
```

## Plugging in a new pipeline stage

Implement each stage and chain them with `GetNextStage`. The last stage returns
`Completed`.

```al
codeunit 50110 "My Validate Stage" implements IIntegrationStage
{
    procedure Run(var IntegrationMessage: Record "Integration Message")
    begin
        // validate the payload; Error() to fail just this stage
    end;

    procedure GetNextStage(): Enum "Integration Stage"
    begin
        exit("Integration Stage"::"My Create Document");
    end;
}

enumextension 50110 "My Pipeline Stages" extends "Integration Stage"
{
    value(50110; "My Validate Payload") { Implementation = IIntegrationStage = "My Validate Stage"; }
    value(50120; "My Create Document")  { Implementation = IIntegrationStage = "My Create Stage"; }
}
```

Start a message on the pipeline:

```al
MessageMgt.CreateMessage(IntegrationMessage, "Integration Direction"::Inbound, MyType);
MessageMgt.StartPipeline(IntegrationMessage, "Integration Stage"::"My Validate Payload");
```

## Swapping the error classifier

```al
codeunit 50120 "My AI Classifier" implements IErrorClassifier
{
    procedure Classify(var IntegrationMessage: Record "Integration Message"): Enum "Integration Error Class"
    begin
        // call your model, return Transient / Permanent / a custom class
    end;
}

enumextension 50120 "My Classifiers" extends "Error Classifier Type"
{
    value(50120; AI) { Implementation = IErrorClassifier = "My AI Classifier"; }
}
```

Then select it on the **Integration Setup** page. No caller changes.

## Scheduling

Schedule three Job Queue entries (Job Queue Category and frequency are yours):

| Codeunit | Purpose |
|---|---|
| 73298411 Integration Dispatcher | Processes New single-handler messages. |
| 73298415 Integration Classifier Job | Classifies failed messages out of band. |
| 73298418 Integration Pipeline Engine | Advances pipeline messages one stage at a time. |

## Telemetry

`Integration Telemetry` emits a stable event per lifecycle transition (IF-0001
staged, through IF-0013 duplicate replay) to Application Insights, with custom
dimensions for Message ID, Correlation ID, Type, Direction, Status, Error Class,
Stage, and Retry Count.

## Permissions

- **Integration Foundation - Full**: read/write and execute. Administrators and
  the integration service account.
- **Integration Foundation - Read**: read-only for operations viewers.

## Verifying the framework (manual smoke check)

This version ships no automated tests and no test app (a deliberate decision; see
`specs/features/001-integration-foundation/spec.md`). To verify a build on a
sandbox, in a small companion app register one test Type and one two-stage
pipeline through the public extension points, then:

1. **Dispatch.** Stage a message of your test type. Run the dispatcher. Confirm it
   resolves and the handler ran.
2. **Duplicate detection.** Stage a second message with the same External Reference
   and Type. Confirm no second side effect and the original Response is returned.
3. **Error classification.** Make the handler `Error`. Run the dispatcher. Confirm
   the message is Failed with the error text captured, then run the classifier job
   and confirm an Error Class is assigned.
4. **Delayed reply.** From a handler, call `ParkAwaitingReply`. Confirm Awaiting
   Reply. Stage a reply with the same Correlation ID and call
   `CompleteAwaitingRequest`; confirm the request resolves and both rows share the
   Correlation ID.
5. **Staged pipeline.** Start a message on your two-stage pipeline. Confirm it
   advances one stage per engine run. Make stage two fail, then Retry from the
   card; confirm only stage two re-runs.
6. **Recovery.** From the card, exercise Retry, Resolve, Resolve by Exception
   (with a reason), and Reassign. Confirm the activity log records each with the
   user, and the Activities cue counts update.
