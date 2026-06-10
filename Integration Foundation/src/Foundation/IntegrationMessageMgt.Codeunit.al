// The single data-access facade for the Integration Message. Every other codeunit,
// page, and consuming app goes through here to create messages, move them through
// their status, read and write payloads, and spawn child work. Concentrating table
// access in one codeunit keeps the state machine in one reviewable place and keeps
// blob encoding consistent (a recurring source of "works on my machine" bugs).
//
// This facade grows pattern by pattern alongside the table: Pattern 1 covers
// creation, the dispatch transitions, and payload access; later patterns add the
// failure (3), park/resume (4), pipeline (5), and recovery (6) operations.
codeunit 73298410 "Integration Message Mgt."
{
    Access = Public;

    var
        IdempotencyMgt: Codeunit "Integration Idempotency Mgt.";
        Telemetry: Codeunit "Integration Telemetry";
        OnlyFailedRetryErr: Label 'Only a failed message can be retried. This message is %1.', Comment = '%1 = current status';
        RetriedTxt: Label 'Reset to New for reprocessing.', Comment = 'Audit log entry written when an operator retries a failed message.';
        ResolvedTxt: Label 'Resolved manually.', Comment = 'Audit log entry written when an operator resolves a message.';
        ResolvedByExceptionTxt: Label 'Resolved by exception (no reprocessing). Reason: %1', Comment = '%1 = the reason captured';
        ReassignedTxt: Label 'Reassigned to %1.', Comment = '%1 = the new owner user id';

    // --- Creation -----------------------------------------------------------

    /// <summary>
    /// Initialise and insert a new staged message. A fresh Message ID is always
    /// assigned. If no Correlation ID is supplied a new one is generated, because
    /// every message must be traceable from the moment it is created.
    /// </summary>
    procedure CreateMessage(var IntegrationMessage: Record "Integration Message"; Direction: Enum "Integration Direction"; IntegrationType: Enum "Integration Type")
    begin
        IntegrationMessage.Init();
        IntegrationMessage."Message ID" := CreateGuid();
        IntegrationMessage.Direction := Direction;
        IntegrationMessage.Type := IntegrationType;
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        if IntegrationMessage."Correlation ID" = '' then
            IntegrationMessage."Correlation ID" := NewCorrelationId();
        IntegrationMessage.Insert(true);
    end;

    /// <summary>
    /// Stage an item arriving from a source system, keyed on its stable external
    /// reference. This is the idempotency gate: if a prior message exists for the
    /// same (External Reference, Type), no new row is created and the existing one
    /// is returned instead, so a duplicate never causes a second side effect.
    /// Returns true when a new message was staged, false when an existing one was
    /// returned (the caller should reply with its stored Response).
    /// </summary>
    procedure StageInbound(IntegrationType: Enum "Integration Type"; ExternalReference: Text; RequestPayload: Text; var IntegrationMessage: Record "Integration Message"): Boolean
    begin
        if (ExternalReference <> '') and IdempotencyMgt.TryGetExisting(IntegrationType, ExternalReference, IntegrationMessage) then begin
            // Duplicate. Hand back the existing message untouched. If it is already
            // resolved, the caller replays its stored response; the retry is
            // indistinguishable from the first attempt.
            if IntegrationMessage.Status = IntegrationMessage.Status::Resolved then
                Telemetry.LogDuplicateReplay(IntegrationMessage);
            exit(false);
        end;

        CreateMessage(IntegrationMessage, IntegrationMessage.Direction::Inbound, IntegrationType);
        IntegrationMessage."External Reference" := CopyStr(ExternalReference, 1, MaxStrLen(IntegrationMessage."External Reference"));
        IntegrationMessage.Modify(true);
        SetRequestText(IntegrationMessage, RequestPayload);
        AppendLog(IntegrationMessage, "Integration Log Event"::Staged, '');
        Telemetry.LogStaged(IntegrationMessage);
        exit(true);
    end;

    /// <summary>
    /// Stage outbound work to notify a downstream system. The message is staged and
    /// left for a background sender; the framework itself never calls out from a
    /// posting path. The sender uses the Message ID as its Idempotency-Key so a
    /// retry to the receiver produces no second side effect there either.
    /// </summary>
    procedure StageOutbound(IntegrationType: Enum "Integration Type"; DocumentNo: Code[40]; RequestPayload: Text; var IntegrationMessage: Record "Integration Message")
    begin
        CreateMessage(IntegrationMessage, IntegrationMessage.Direction::Outbound, IntegrationType);
        IntegrationMessage."Document No." := DocumentNo;
        IntegrationMessage.Modify(true);
        SetRequestText(IntegrationMessage, RequestPayload);
        AppendLog(IntegrationMessage, "Integration Log Event"::Staged, '');
        Telemetry.LogStaged(IntegrationMessage);
    end;

    /// <summary>
    /// Spawn a child message from a parent (a pipeline stage creating downstream
    /// work, for example). The child inherits the parent's Correlation ID and
    /// points back at it, so the parent/child tree stays traceable.
    /// </summary>
    procedure SpawnChild(var ParentMessage: Record "Integration Message"; Direction: Enum "Integration Direction"; IntegrationType: Enum "Integration Type"; var ChildMessage: Record "Integration Message")
    begin
        ChildMessage.Init();
        ChildMessage."Correlation ID" := ParentMessage."Correlation ID";
        CreateMessage(ChildMessage, Direction, IntegrationType);
        ChildMessage."Parent Message ID" := ParentMessage."Message ID";
        ChildMessage."Document No." := ParentMessage."Document No.";
        ChildMessage.Modify(true);
    end;

    /// <summary>
    /// Put a message onto a pipeline at its first stage. The pipeline engine (not
    /// the dispatcher) then owns it: a non-None Current Stage is what distinguishes
    /// a pipeline message from a single-handler one.
    /// </summary>
    procedure StartPipeline(var IntegrationMessage: Record "Integration Message"; FirstStage: Enum "Integration Stage")
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        IntegrationMessage."Current Stage" := FirstStage;
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        IntegrationMessage.Modify(true);
        Telemetry.LogStaged(IntegrationMessage);
    end;

    procedure NewCorrelationId(): Code[40]
    begin
        // A GUID formatted without braces fits Code[40] and is unique enough to be
        // the trace id across BC, queues, and external systems.
        exit(CopyStr(Format(CreateGuid(), 0, 4), 1, 40));
    end;

    // --- Dispatch transitions ----------------------------------------------

    /// <summary>
    /// Move a message into processing. The caller commits this before running the
    /// handler so the In Progress state is durable: a crash leaves a visible
    /// In Progress row (which stale-lock recovery can reset), and a concurrent run
    /// sees it is already being worked.
    /// </summary>
    procedure MarkInProgress(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.Status := IntegrationMessage.Status::"In Progress";
        IntegrationMessage."Processed At" := CurrentDateTime();
        IntegrationMessage.Modify(true);
    end;

    /// <summary>
    /// Mark a message resolved. Called by the dispatcher when a handler returns
    /// without error and did not itself park the message (Awaiting Reply).
    /// </summary>
    procedure MarkResolved(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.Status := IntegrationMessage.Status::Resolved;
        IntegrationMessage."Resolved At" := CurrentDateTime();
        IntegrationMessage.Modify(true);
    end;

    // --- Manual recovery (Pattern 6) ---------------------------------------

    /// <summary>
    /// Retry a failed message. It returns to New with the same Message ID, so the
    /// right engine (dispatcher for a single-handler message, pipeline engine for a
    /// pipeline message) reprocesses it. The idempotency key is unchanged, so a
    /// retry cannot cause a second side effect. Only failed messages can be retried.
    /// </summary>
    procedure Retry(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        if IntegrationMessage.Status <> IntegrationMessage.Status::Failed then
            Error(OnlyFailedRetryErr, Format(IntegrationMessage.Status));

        IntegrationMessage.Status := IntegrationMessage.Status::New;
        IntegrationMessage.Modify(true);
        AppendLog(IntegrationMessage, "Integration Log Event"::Retried, RetriedTxt);
        Commit();
        Telemetry.LogRetried(IntegrationMessage);
    end;

    /// <summary>
    /// Resolve a message manually (an operator decided it is handled, perhaps fixed
    /// outside the system). No reprocessing happens; the audit trail is kept.
    /// </summary>
    procedure Resolve(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        MarkResolved(IntegrationMessage);
        AppendLog(IntegrationMessage, "Integration Log Event"::Resolved, ResolvedTxt);
        Commit();
        Telemetry.LogResolved(IntegrationMessage);
    end;

    /// <summary>
    /// Resolve by exception: close the message without reprocessing and record why.
    /// Used when the work will never succeed as-is and the operator accepts that.
    /// The reason is kept on the audit trail.
    /// </summary>
    procedure ResolveByException(var IntegrationMessage: Record "Integration Message"; Reason: Text)
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        MarkResolved(IntegrationMessage);
        AppendLog(IntegrationMessage, "Integration Log Event"::"Resolved By Exception", StrSubstNo(ResolvedByExceptionTxt, Reason));
        Commit();
        Telemetry.LogResolvedByException(IntegrationMessage);
    end;

    /// <summary>
    /// Reassign a message to another user for triage or fixing. Status is unchanged;
    /// only ownership moves, so work can be split across a team.
    /// </summary>
    procedure Reassign(var IntegrationMessage: Record "Integration Message"; NewUserId: Code[50])
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        IntegrationMessage."Assigned To User ID" := NewUserId;
        IntegrationMessage.Modify(true);
        AppendLog(IntegrationMessage, "Integration Log Event"::Reassigned, StrSubstNo(ReassignedTxt, NewUserId));
        Commit();
        Telemetry.LogReassigned(IntegrationMessage);
    end;

    /// <summary>
    /// Append an entry to a message's audit trail. The framework records its own
    /// milestones and manual actions through here; a consuming app can record its
    /// own domain events against a message the same way.
    /// </summary>
    procedure AppendLog(var IntegrationMessage: Record "Integration Message"; Event: Enum "Integration Log Event"; Description: Text)
    var
        MessageLog: Record "Integration Message Log";
    begin
        MessageLog.Init();
        MessageLog."Message ID" := IntegrationMessage."Message ID";
        MessageLog.Event := Event;
        MessageLog.Description := CopyStr(Description, 1, MaxStrLen(MessageLog.Description));
        MessageLog."Logged At" := CurrentDateTime();
        MessageLog."Logged By" := CopyStr(UserId(), 1, MaxStrLen(MessageLog."Logged By"));
        MessageLog.Insert(true);
    end;

    // --- Payload access -----------------------------------------------------
    // Blob fields are not loaded when a record is read, so a read always CalcFields
    // first. UTF-8 throughout so payloads round-trip regardless of content.

    procedure SetRequestText(var IntegrationMessage: Record "Integration Message"; PayloadText: Text)
    var
        OutStream: OutStream;
    begin
        Clear(IntegrationMessage.Request);
        IntegrationMessage.Request.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.Write(PayloadText);
        IntegrationMessage.Modify(true);
    end;

    procedure GetRequestText(var IntegrationMessage: Record "Integration Message"): Text
    begin
        exit(ReadBlobText(IntegrationMessage, IntegrationMessage.FieldNo(Request)));
    end;

    procedure SetResponseText(var IntegrationMessage: Record "Integration Message"; PayloadText: Text)
    var
        OutStream: OutStream;
    begin
        Clear(IntegrationMessage.Response);
        IntegrationMessage.Response.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.Write(PayloadText);
        IntegrationMessage.Modify(true);
    end;

    procedure GetResponseText(var IntegrationMessage: Record "Integration Message"): Text
    begin
        exit(ReadBlobText(IntegrationMessage, IntegrationMessage.FieldNo(Response)));
    end;

    procedure SetErrorText(var IntegrationMessage: Record "Integration Message"; ErrorText: Text)
    var
        OutStream: OutStream;
    begin
        Clear(IntegrationMessage."Error Message");
        IntegrationMessage."Error Message".CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.Write(ErrorText);
        IntegrationMessage.Modify(true);
    end;

    procedure GetErrorText(var IntegrationMessage: Record "Integration Message"): Text
    begin
        exit(ReadBlobText(IntegrationMessage, IntegrationMessage.FieldNo("Error Message")));
    end;

    local procedure ReadBlobText(var IntegrationMessage: Record "Integration Message"; BlobFieldNo: Integer): Text
    var
        InStream: InStream;
        PayloadText: Text;
    begin
        case BlobFieldNo of
            IntegrationMessage.FieldNo(Request):
                begin
                    IntegrationMessage.CalcFields(Request);
                    if not IntegrationMessage.Request.HasValue() then
                        exit('');
                    IntegrationMessage.Request.CreateInStream(InStream, TextEncoding::UTF8);
                end;
            IntegrationMessage.FieldNo(Response):
                begin
                    IntegrationMessage.CalcFields(Response);
                    if not IntegrationMessage.Response.HasValue() then
                        exit('');
                    IntegrationMessage.Response.CreateInStream(InStream, TextEncoding::UTF8);
                end;
            IntegrationMessage.FieldNo("Error Message"):
                begin
                    IntegrationMessage.CalcFields("Error Message");
                    if not IntegrationMessage."Error Message".HasValue() then
                        exit('');
                    IntegrationMessage."Error Message".CreateInStream(InStream, TextEncoding::UTF8);
                end;
        end;
        InStream.Read(PayloadText);
        exit(PayloadText);
    end;
}
