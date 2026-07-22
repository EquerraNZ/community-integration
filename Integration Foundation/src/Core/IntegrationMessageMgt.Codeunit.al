codeunit 73298420 "Integration Message Mgt."
{
    // The single data-access seam for the Integration Message table. Every feature
    // stages, transitions, and fails messages through here; no other object touches
    // the table directly. Keeping the table behind one codeunit is what lets the
    // dedup, correlation, classification, and audit rules be enforced in one place.

    var
        Telemetry: Codeunit "Integration Telemetry";
        StagedTok: Label 'Integration message staged.', Locked = true;
        DedupHitTok: Label 'Duplicate inbound delivery ignored; existing message returned.', Locked = true;
        InProgressTok: Label 'Integration message dispatch started.', Locked = true;
        ResolvedTok: Label 'Integration message resolved.', Locked = true;
        FailedTok: Label 'Integration message failed.', Locked = true;
        OutboundStagedTok: Label 'Outbound integration message staged.', Locked = true;
        EventFiredTok: Label 'Outbound integration event fired.', Locked = true;
        // The error-class contract is carried as a sentinel prefix on the error text,
        // because GetLastErrorObject (and its custom dimensions) is OnPrem-only and not
        // available to extensions. The handler raises CreatePermanentError(...) /
        // CreateTransientError(...); the failure path reads the prefix back through the
        // extension-safe GetLastErrorText and strips it before storing the message.
        PermanentMarkerTok: Label 'INTCLASS:PERMANENT:', Locked = true;
        TransientMarkerTok: Label 'INTCLASS:TRANSIENT:', Locked = true;

    /// <summary>
    /// Stage one inbound message, deduplicating on (External Reference, Type) first.
    /// On a hit the existing Message ID is returned and nothing new is inserted, so a
    /// re-delivery is a no-op. The correlation id is set once here, from the supplied
    /// value or the external reference, and never regenerated downstream.
    /// </summary>
    procedure StageInbound(TypeCode: Text; ExternalReference: Text[100]; CorrelationId: Code[40]; Payload: Text) MessageId: Guid
    var
        ExistingMessage: Record "Integration Message";
        IntegrationMessage: Record "Integration Message";
        MsgType: Enum "Integration Message Type";
    begin
        MsgType := ResolveType(TypeCode);

        ExistingMessage.SetLoadFields("Message ID", Status);
        ExistingMessage.SetRange("External Reference", ExternalReference);
        ExistingMessage.SetRange(Type, MsgType);
        if ExistingMessage.FindFirst() then begin
            Telemetry.LogMessageEvent('INT-0002', DedupHitTok, Verbosity::Normal, ExistingMessage);
            exit(ExistingMessage."Message ID");
        end;

        IntegrationMessage.Init();
        IntegrationMessage."Message ID" := CreateGuid();
        IntegrationMessage.Direction := IntegrationMessage.Direction::Inbound;
        IntegrationMessage.Type := MsgType;
        IntegrationMessage."Type Code" := CopyStr(TypeCode, 1, MaxStrLen(IntegrationMessage."Type Code"));
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        IntegrationMessage."External Reference" := ExternalReference;
        IntegrationMessage."Correlation ID" := ResolveCorrelationId(CorrelationId, ExternalReference);
        IntegrationMessage.SetRequest(Payload);
        StampCreated(IntegrationMessage);
        // The unique idempotency key makes a racing duplicate Insert fail here rather
        // than slip through the FindFirst above, so the message stages at most once.
        IntegrationMessage.Insert(true);

        Telemetry.LogMessageEvent('INT-0001', StagedTok, Verbosity::Normal, IntegrationMessage);
        exit(IntegrationMessage."Message ID");
    end;

    /// <summary>
    /// Stage one outbound message as the correlation parent for a request that the
    /// integration layer will send (used by the fulfilment-request flow). Outbound
    /// rows park Awaiting Reply until their confirmation arrives as a fresh inbound
    /// message sharing the correlation id.
    /// </summary>
    procedure StageOutbound(TypeCode: Text; ExternalReference: Text[100]; CorrelationId: Code[40]; DocumentNo: Code[40]; Payload: Text) MessageId: Guid
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.Init();
        IntegrationMessage."Message ID" := CreateGuid();
        IntegrationMessage.Direction := IntegrationMessage.Direction::Outbound;
        IntegrationMessage.Type := ResolveType(TypeCode);
        IntegrationMessage."Type Code" := CopyStr(TypeCode, 1, MaxStrLen(IntegrationMessage."Type Code"));
        IntegrationMessage.Status := IntegrationMessage.Status::"Awaiting Reply";
        IntegrationMessage."External Reference" := ExternalReference;
        IntegrationMessage."Correlation ID" := ResolveCorrelationId(CorrelationId, ExternalReference);
        IntegrationMessage."Document No." := DocumentNo;
        IntegrationMessage.SetRequest(Payload);
        StampCreated(IntegrationMessage);
        IntegrationMessage.Insert(true);

        Telemetry.LogMessageEvent('INT-0006', OutboundStagedTok, Verbosity::Normal, IntegrationMessage);
        exit(IntegrationMessage."Message ID");
    end;

    /// <summary>Move a message to In Progress before its handler runs.</summary>
    procedure MarkInProgress(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.Status := IntegrationMessage.Status::"In Progress";
        StampModified(IntegrationMessage);
        IntegrationMessage.Modify(true);
        Telemetry.LogMessageEvent('INT-0003', InProgressTok, Verbosity::Normal, IntegrationMessage);
    end;

    /// <summary>Mark a message Resolved after its handler succeeded.</summary>
    procedure MarkResolved(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.Status := IntegrationMessage.Status::Resolved;
        IntegrationMessage."Error Message" := '';
        IntegrationMessage."Error Class" := IntegrationMessage."Error Class"::None;
        StampModified(IntegrationMessage);
        IntegrationMessage.Modify(true);
        Telemetry.LogMessageEvent('INT-0004', ResolvedTok, Verbosity::Normal, IntegrationMessage);
    end;

    /// <summary>
    /// Record a handler failure: store the error text and its class, then either
    /// re-queue (Transient, within the retry budget) or leave the message Failed for
    /// manual resolution (Permanent, or Transient past the budget). Permanent never
    /// increments the retry count.
    /// </summary>
    procedure Fail(var IntegrationMessage: Record "Integration Message"; ErrorText: Text)
    var
        ErrorClass: Enum "Integration Error Class";
        CleanText: Text;
    begin
        ErrorClass := ClassifyAndStrip(ErrorText, CleanText);

        IntegrationMessage."Error Message" := CopyStr(CleanText, 1, MaxStrLen(IntegrationMessage."Error Message"));
        IntegrationMessage."Error Class" := ErrorClass;

        if (ErrorClass = ErrorClass::Transient) and (IntegrationMessage."Retry Count" < GetMaxRetries()) then begin
            IntegrationMessage."Retry Count" += 1;
            IntegrationMessage.Status := IntegrationMessage.Status::New; // re-queued for the next scheduled dispatch
        end else
            IntegrationMessage.Status := IntegrationMessage.Status::Failed;

        StampModified(IntegrationMessage);
        IntegrationMessage.Modify(true);
        Telemetry.LogMessageEvent('INT-0005', FailedTok, Verbosity::Warning, IntegrationMessage);
    end;

    /// <summary>
    /// Build the error text a handler raises (via Error) to signal a permanent data
    /// problem the dispatcher must not retry. The class travels as a sentinel prefix on
    /// the text, which the failure path reads back through GetLastErrorText (the
    /// extension-safe call) and strips before storing.
    /// </summary>
    procedure CreatePermanentError(Message: Text): Text
    begin
        exit(PermanentMarkerTok + Message);
    end;

    /// <summary>Build the error text a handler raises (via Error) to signal a transient
    /// (retryable) failure.</summary>
    procedure CreateTransientError(Message: Text): Text
    begin
        exit(TransientMarkerTok + Message);
    end;

    /// <summary>
    /// True when an outbound message of the given type already exists for the external
    /// reference. Used by outbound flows to stay idempotent (notify at most once).
    /// </summary>
    procedure OutboundExists(TypeCode: Text; ExternalReference: Text): Boolean
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.SetRange(Direction, IntegrationMessage.Direction::Outbound);
        IntegrationMessage.SetRange(Type, ResolveType(TypeCode));
        IntegrationMessage.SetRange("External Reference", CopyStr(ExternalReference, 1, MaxStrLen(IntegrationMessage."External Reference")));
        exit(not IntegrationMessage.IsEmpty());
    end;

    /// <summary>
    /// Find the outbound message of a given type for an external reference (the
    /// correlation parent of a later inbound confirmation). Returns its Message ID, or
    /// an empty Guid if none. Routes the lookup through the seam so handlers do not read
    /// the table directly.
    /// </summary>
    procedure FindOutboundParent(TypeCode: Text; ExternalReference: Text) ParentMessageId: Guid
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.SetRange(Direction, IntegrationMessage.Direction::Outbound);
        IntegrationMessage.SetRange(Type, ResolveType(TypeCode));
        IntegrationMessage.SetRange("External Reference", CopyStr(ExternalReference, 1, MaxStrLen(IntegrationMessage."External Reference")));
        if IntegrationMessage.FindFirst() then
            exit(IntegrationMessage."Message ID");
        Clear(ParentMessageId);
    end;

    /// <summary>
    /// Emit the protected-step telemetry for an outbound event being fired (the
    /// tech-design lists "event fired" as a telemetry step). The message id is the
    /// outbound parent staged just before the event was raised.
    /// </summary>
    procedure LogEventFired(MessageId: Guid)
    var
        IntegrationMessage: Record "Integration Message";
    begin
        if IntegrationMessage.Get(MessageId) then
            Telemetry.LogMessageEvent('INT-0013', EventFiredTok, Verbosity::Normal, IntegrationMessage);
    end;

    /// <summary>
    /// Map the external Type Code string onto the routing enum by matching the value
    /// name. An unrecognised code resolves to Unknown, whose handler fails the message
    /// Permanent rather than skipping it silently.
    /// </summary>
    procedure ResolveType(TypeCode: Text): Enum "Integration Message Type"
    var
        MsgType: Enum "Integration Message Type";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
    begin
        Names := MsgType.Names();
        Ordinals := MsgType.Ordinals();
        for Index := 1 to Names.Count() do
            if Names.Get(Index) = TypeCode then
                exit("Integration Message Type".FromInteger(Ordinals.Get(Index)));
        exit(MsgType::Unknown);
    end;

    local procedure ClassifyAndStrip(ErrorText: Text; var CleanText: Text): Enum "Integration Error Class"
    begin
        // Default to Transient: an unexpected runtime error (a lock, a timeout) is
        // worth one bounded retry; only an explicit Permanent signal fails outright.
        if ErrorText.StartsWith(PermanentMarkerTok) then begin
            CleanText := CopyStr(ErrorText, StrLen(PermanentMarkerTok) + 1);
            exit("Integration Error Class"::Permanent);
        end;
        if ErrorText.StartsWith(TransientMarkerTok) then begin
            CleanText := CopyStr(ErrorText, StrLen(TransientMarkerTok) + 1);
            exit("Integration Error Class"::Transient);
        end;
        CleanText := ErrorText;
        exit("Integration Error Class"::Transient);
    end;

    local procedure ResolveCorrelationId(CorrelationId: Code[40]; ExternalReference: Text[100]): Code[40]
    begin
        if CorrelationId <> '' then
            exit(CorrelationId);
        exit(CopyStr(ExternalReference, 1, MaxStrLen(CorrelationId)));
    end;

    local procedure GetMaxRetries(): Integer
    var
        IntegrationSetup: Record "Integration Setup";
    begin
        if IntegrationSetup.Get() and (IntegrationSetup."Max Retry Count" > 0) then
            exit(IntegrationSetup."Max Retry Count");
        exit(3);
    end;

    local procedure StampCreated(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage."Created At" := CurrentDateTime();
        IntegrationMessage."Created By User" := CopyStr(UserId(), 1, MaxStrLen(IntegrationMessage."Created By User"));
        IntegrationMessage."Last Modified At" := IntegrationMessage."Created At";
        IntegrationMessage."Last Modified By User" := IntegrationMessage."Created By User";
    end;

    /// <summary>Stamp the modified-audit fields. Shared so every state transition,
    /// including manual resolution, records who touched the message and when.</summary>
    procedure StampModified(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage."Last Modified At" := CurrentDateTime();
        IntegrationMessage."Last Modified By User" := CopyStr(UserId(), 1, MaxStrLen(IntegrationMessage."Last Modified By User"));
    end;
}
