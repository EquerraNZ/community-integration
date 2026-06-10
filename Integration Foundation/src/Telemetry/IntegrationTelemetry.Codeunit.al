// One place that emits the lifecycle telemetry, so every event carries the same
// stable shape: a stable event id (IF-xxxx) an administrator can build an alert on,
// and the same custom dimensions (Message ID, Correlation ID, Type, Direction,
// Status, plus Error Class and Stage where relevant). The house rule is that every
// protected operation emits; routing them all through here keeps that honest and
// keeps the dimension names from drifting between call sites.
//
// SingleInstance because it holds no state and is called on hot paths; one instance
// avoids re-creating the codeunit on every emit.
codeunit 73298420 "Integration Telemetry"
{
    SingleInstance = true;
    Access = Public;

    var
        StagedLbl: Label 'Integration message staged.', Locked = true;
        DispatchedLbl: Label 'Integration message dispatched to handler.', Locked = true;
        SucceededLbl: Label 'Integration handler succeeded.', Locked = true;
        FailedLbl: Label 'Integration handler failed.', Locked = true;
        ClassifiedLbl: Label 'Integration error classified.', Locked = true;
        ParkedLbl: Label 'Integration message parked awaiting reply.', Locked = true;
        ReplyMatchedLbl: Label 'Integration reply matched to request.', Locked = true;
        StageAdvancedLbl: Label 'Integration pipeline stage advanced.', Locked = true;
        RetriedLbl: Label 'Integration message retried.', Locked = true;
        ResolvedLbl: Label 'Integration message resolved.', Locked = true;
        ResolvedByExceptionLbl: Label 'Integration message resolved by exception.', Locked = true;
        ReassignedLbl: Label 'Integration message reassigned.', Locked = true;
        DedupReplayLbl: Label 'Integration duplicate detected; stored response replayed.', Locked = true;

    procedure LogStaged(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0001', StagedLbl, IntegrationMessage);
    end;

    procedure LogDispatched(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0002', DispatchedLbl, IntegrationMessage);
    end;

    procedure LogSucceeded(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0003', SucceededLbl, IntegrationMessage);
    end;

    procedure LogFailed(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0004', FailedLbl, IntegrationMessage);
    end;

    procedure LogClassified(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0005', ClassifiedLbl, IntegrationMessage);
    end;

    procedure LogParked(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0006', ParkedLbl, IntegrationMessage);
    end;

    procedure LogReplyMatched(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0007', ReplyMatchedLbl, IntegrationMessage);
    end;

    procedure LogStageAdvanced(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0008', StageAdvancedLbl, IntegrationMessage);
    end;

    procedure LogRetried(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0009', RetriedLbl, IntegrationMessage);
    end;

    procedure LogResolved(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0010', ResolvedLbl, IntegrationMessage);
    end;

    procedure LogResolvedByException(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0011', ResolvedByExceptionLbl, IntegrationMessage);
    end;

    procedure LogReassigned(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0012', ReassignedLbl, IntegrationMessage);
    end;

    procedure LogDuplicateReplay(var IntegrationMessage: Record "Integration Message")
    begin
        Emit('IF-0013', DedupReplayLbl, IntegrationMessage);
    end;

    local procedure Emit(EventId: Text; Message: Text; var IntegrationMessage: Record "Integration Message")
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('messageId', Format(IntegrationMessage."Message ID", 0, 4));
        Dimensions.Add('correlationId', IntegrationMessage."Correlation ID");
        Dimensions.Add('type', Format(IntegrationMessage.Type));
        Dimensions.Add('direction', Format(IntegrationMessage.Direction));
        Dimensions.Add('status', Format(IntegrationMessage.Status));
        Dimensions.Add('errorClass', Format(IntegrationMessage."Error Class"));
        Dimensions.Add('stage', Format(IntegrationMessage."Current Stage"));
        Dimensions.Add('retryCount', Format(IntegrationMessage."Retry Count"));

        // VerboseAll publishes to the partner's and the customer's Application
        // Insights, which is what an operations team monitoring the integration
        // queue needs. The event id is stable so alerts survive message text edits.
        Session.LogMessage(EventId, Message, Verbosity::Normal, DataClassification::SystemMetadata,
            TelemetryScope::All, Dimensions);
    end;
}
