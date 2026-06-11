codeunit 73298426 "Integration Resolution Mgt."
{
    // The three manual-resolution behaviours, kept out of the pages so the pages stay
    // thin. Every action reuses the existing Message ID, so a human-driven re-run is
    // as duplicate-safe as an automated one: the idempotency key never changes.

    var
        Telemetry: Codeunit "Integration Telemetry";
        MessageMgt: Codeunit "Integration Message Mgt.";
        NotFailedErr: Label 'Only a Failed message can be resolved. This message is %1.', Comment = '%1 = the current status';
        ResolveTok: Label 'Failed integration message re-queued for retry.', Locked = true;
        ConfirmTok: Label 'Failed integration message confirmed by exception.', Locked = true;
        ReassignTok: Label 'Failed integration message reassigned and re-queued.', Locked = true;

    /// <summary>
    /// Re-queue a corrected message: clear the error and set it back to New so the
    /// dispatcher re-runs it under the same Message ID on its next pass.
    /// </summary>
    procedure Resolve(var IntegrationMessage: Record "Integration Message")
    begin
        GuardFailed(IntegrationMessage);
        IntegrationMessage."Error Message" := '';
        IntegrationMessage."Error Class" := IntegrationMessage."Error Class"::None;
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        MessageMgt.StampModified(IntegrationMessage);
        IntegrationMessage.Modify(true);
        Telemetry.LogMessageEvent('INT-0008', ResolveTok, Verbosity::Normal, IntegrationMessage);
    end;

    /// <summary>
    /// Accept the message as handled with no retry. The error text is preserved for
    /// the audit trail; the Retry Count is left untouched.
    /// </summary>
    procedure ConfirmByException(var IntegrationMessage: Record "Integration Message")
    begin
        GuardFailed(IntegrationMessage);
        IntegrationMessage.Status := IntegrationMessage.Status::Resolved;
        MessageMgt.StampModified(IntegrationMessage);
        IntegrationMessage.Modify(true);
        Telemetry.LogMessageEvent('INT-0009', ConfirmTok, Verbosity::Normal, IntegrationMessage);
    end;

    /// <summary>
    /// Re-route a message staged against the wrong type: re-resolve the routing enum
    /// from the (corrected) Type Code, then re-queue under the same Message ID.
    /// </summary>
    procedure Reassign(var IntegrationMessage: Record "Integration Message")
    begin
        GuardFailed(IntegrationMessage);
        IntegrationMessage.Type := MessageMgt.ResolveType(IntegrationMessage."Type Code");
        IntegrationMessage."Error Message" := '';
        IntegrationMessage."Error Class" := IntegrationMessage."Error Class"::None;
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        MessageMgt.StampModified(IntegrationMessage);
        IntegrationMessage.Modify(true);
        Telemetry.LogMessageEvent('INT-0010', ReassignTok, Verbosity::Normal, IntegrationMessage);
    end;

    local procedure GuardFailed(var IntegrationMessage: Record "Integration Message")
    begin
        if IntegrationMessage.Status <> IntegrationMessage.Status::Failed then
            Error(NotFailedErr, Format(IntegrationMessage.Status));
    end;
}
