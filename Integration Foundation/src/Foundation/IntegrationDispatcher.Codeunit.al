// The dispatch engine. Scheduled as a Job Queue entry, it picks up New
// single-handler messages and routes each to its handler by Type. The engine is
// closed for modification and open for extension: adding an integration never
// touches this codeunit, because the Type enum resolves the handler.
//
// The processing shape is deliberate:
//   1. Claim the message (lock, re-check it is still New) so two Job Queue runs
//      never process the same row.
//   2. Mark In Progress and Commit, so the claim is durable before any work.
//   3. Run the handler inside Codeunit.Run isolation.
//   4. On success, resolve it (unless the handler parked it Awaiting Reply).
//      On failure, record the failure durably (enriched in Pattern 3) without the
//      rolled-back handler work taking the failure record with it.
codeunit 73298411 "Integration Dispatcher"
{
    Access = Public;

    trigger OnRun()
    begin
        ProcessNewMessages();
    end;

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        IdempotencyMgt: Codeunit "Integration Idempotency Mgt.";
        Telemetry: Codeunit "Integration Telemetry";

    /// <summary>
    /// Scan the New single-handler messages and dispatch each. The candidate ids
    /// are collected up front so the per-message commits do not disturb a live
    /// FindSet cursor.
    /// </summary>
    procedure ProcessNewMessages()
    var
        IntegrationMessage: Record "Integration Message";
        MessageIds: List of [Guid];
        MessageId: Guid;
    begin
        IntegrationMessage.SetCurrentKey(Status, Direction, SystemCreatedAt);
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        // Pipeline messages (a real Current Stage) belong to the pipeline engine,
        // not the dispatcher. The dispatcher owns single-handler messages only.
        IntegrationMessage.SetRange("Current Stage", "Integration Stage"::None);
        IntegrationMessage.SetLoadFields("Message ID");
        if IntegrationMessage.FindSet() then
            repeat
                MessageIds.Add(IntegrationMessage."Message ID");
            until IntegrationMessage.Next() = 0;

        foreach MessageId in MessageIds do
            DispatchById(MessageId);
    end;

    local procedure DispatchById(MessageId: Guid)
    var
        IntegrationMessage: Record "Integration Message";
    begin
        if not ClaimMessage(MessageId, IntegrationMessage) then
            exit;
        // Safety-net idempotency: if a resolved twin reached processing by any path
        // (a direct API insert that skipped StageInbound, for example), replay its
        // response and resolve without running the handler again. No second side
        // effect, and the caller cannot tell this from the first attempt.
        if ReplayResolvedDuplicate(IntegrationMessage) then
            exit;
        Telemetry.LogDispatched(IntegrationMessage);
        RunHandler(IntegrationMessage);
    end;

    local procedure ReplayResolvedDuplicate(var IntegrationMessage: Record "Integration Message"): Boolean
    var
        TwinMessage: Record "Integration Message";
    begin
        if not IdempotencyMgt.TryGetResolvedTwin(IntegrationMessage.Type, IntegrationMessage."External Reference", IntegrationMessage."Message ID", TwinMessage) then
            exit(false);
        MessageMgt.SetResponseText(IntegrationMessage, MessageMgt.GetResponseText(TwinMessage));
        MessageMgt.MarkResolved(IntegrationMessage);
        Commit();
        Telemetry.LogDuplicateReplay(IntegrationMessage);
        exit(true);
    end;

    /// <summary>
    /// Atomically claim a New message: take an update lock, re-read, and only
    /// proceed if it is still New. The In Progress write is committed so the claim
    /// survives a crash and is visible to a concurrent runner.
    /// </summary>
    local procedure ClaimMessage(MessageId: Guid; var IntegrationMessage: Record "Integration Message"): Boolean
    begin
        IntegrationMessage.LockTable();
        if not IntegrationMessage.Get(MessageId) then
            exit(false);
        if IntegrationMessage.Status <> IntegrationMessage.Status::New then
            exit(false);
        MessageMgt.MarkInProgress(IntegrationMessage);
        Commit();
        exit(true);
    end;

    local procedure RunHandler(var IntegrationMessage: Record "Integration Message")
    var
        HandlerRunner: Codeunit "Integration Handler Runner";
        ErrorText: Text;
    begin
        // Codeunit.Run gives the handler its own transaction. A false return means
        // it errored and its own work rolled back; the committed In Progress state
        // is untouched, so we can record the outcome cleanly.
        if HandlerRunner.Run(IntegrationMessage) then begin
            CompleteSuccess(IntegrationMessage);
            exit;
        end;

        // Read the error before anything else clears it, then hand it to the error
        // handler for durable capture. Classification happens later, out of band.
        ErrorText := GetLastErrorText();
        CompleteFailure(IntegrationMessage, ErrorText);
    end;

    local procedure CompleteSuccess(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        // A handler may have parked the message (Awaiting Reply) for a long-running
        // flow. Only the dispatcher's own "still In Progress" case resolves it.
        if IntegrationMessage.Status <> IntegrationMessage.Status::"In Progress" then
            exit;
        MessageMgt.MarkResolved(IntegrationMessage);
        Commit();
        Telemetry.LogSucceeded(IntegrationMessage);
    end;

    local procedure CompleteFailure(var IntegrationMessage: Record "Integration Message"; ErrorText: Text)
    var
        ErrorHandler: Codeunit "Integration Error Handler";
    begin
        // Capture the error durably and leave the message Failed and unclassified;
        // the classifier job assigns the class out of band. Telemetry for the
        // failure is emitted by the error handler.
        ErrorHandler.Capture(IntegrationMessage, ErrorText);
    end;
}
