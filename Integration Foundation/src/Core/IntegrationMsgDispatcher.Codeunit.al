codeunit 73298421 "Integration Msg. Dispatcher"
{
    // The Job Queue runner. Reads New inbound messages by the dispatch key and runs
    // each through its handler, isolating failures per message. Nothing here calls an
    // external service or posts inline; it only routes staged rows to handlers.

    trigger OnRun()
    begin
        DispatchNewMessages();
    end;

    /// <summary>Process every New inbound message, oldest first.</summary>
    procedure DispatchNewMessages()
    var
        IntegrationMessage: Record "Integration Message";
        MessageIds: List of [Guid];
        MessageId: Guid;
    begin
        // Collect the work-list first so re-queued (Transient) messages set back to New
        // by a failure in this run are not re-picked within the same pass.
        IntegrationMessage.SetCurrentKey(Status, Direction, "Created At");
        IntegrationMessage.SetLoadFields("Message ID");
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        IntegrationMessage.SetRange(Direction, IntegrationMessage.Direction::Inbound);
        if IntegrationMessage.FindSet() then
            repeat
                MessageIds.Add(IntegrationMessage."Message ID");
            until IntegrationMessage.Next() = 0;

        foreach MessageId in MessageIds do
            ProcessMessage(MessageId);
    end;

    local procedure ProcessMessage(MessageId: Guid)
    var
        IntegrationMessage: Record "Integration Message";
        MessageMgt: Codeunit "Integration Message Mgt.";
        Processor: Codeunit "Integration Msg. Processor";
        ErrorText: Text;
    begin
        if not IntegrationMessage.Get(MessageId) then
            exit;
        if IntegrationMessage.Status <> IntegrationMessage.Status::New then
            exit;

        MessageMgt.MarkInProgress(IntegrationMessage);
        // Commit the In Progress marker so a mid-run session loss cannot strand the
        // message as New (double-processed) and so the handler's own rollback on
        // failure cannot undo the status transition. This per-message commit is the
        // staged-processing boundary, intentional rather than an accidental loop commit.
        Commit();

        ClearLastError();
        if Processor.Run(IntegrationMessage) then begin
            IntegrationMessage.Get(MessageId); // reload the handler's persisted changes
            MessageMgt.MarkResolved(IntegrationMessage);
        end else begin
            ErrorText := GetLastErrorText();
            IntegrationMessage.Get(MessageId);
            MessageMgt.Fail(IntegrationMessage, ErrorText);
        end;
    end;
}
