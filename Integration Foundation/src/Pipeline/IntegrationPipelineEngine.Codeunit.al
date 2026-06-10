// The staged-pipeline engine. Scheduled as its own Job Queue entry, it advances
// pipeline messages one stage per cycle. Each stage is a short unit of work with
// its own lock window and its own retry, which is the whole point: a failure rolls
// back and retries only the failed stage, never the stages that already ran.
//
// The cursor is the Current Stage field. On success the engine moves it to the
// stage's declared successor and flips Status back to New, so the next cycle picks
// up the next stage. When the successor is Completed the message is resolved. On
// failure the cursor stays put and Status becomes Failed, so a manual retry
// (Failed -> New) re-runs exactly the stage that failed.
codeunit 73298418 "Integration Pipeline Engine"
{
    Access = Public;

    trigger OnRun()
    begin
        AdvancePipelines();
    end;

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        Telemetry: Codeunit "Integration Telemetry";

    /// <summary>
    /// Scan the New pipeline messages (those with a real stage cursor) and advance
    /// each by one stage. Candidate ids are collected up front so the per-message
    /// commits do not disturb a live FindSet cursor.
    /// </summary>
    procedure AdvancePipelines()
    var
        IntegrationMessage: Record "Integration Message";
        MessageIds: List of [Guid];
        MessageId: Guid;
    begin
        IntegrationMessage.SetCurrentKey("Current Stage", Status);
        IntegrationMessage.SetFilter("Current Stage", '<>%1&<>%2', "Integration Stage"::None, "Integration Stage"::Completed);
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        IntegrationMessage.SetLoadFields("Message ID");
        if IntegrationMessage.FindSet() then
            repeat
                MessageIds.Add(IntegrationMessage."Message ID");
            until IntegrationMessage.Next() = 0;

        foreach MessageId in MessageIds do
            AdvanceById(MessageId);
    end;

    local procedure AdvanceById(MessageId: Guid)
    var
        IntegrationMessage: Record "Integration Message";
    begin
        if not ClaimStage(MessageId, IntegrationMessage) then
            exit;
        RunStage(IntegrationMessage);
    end;

    /// <summary>
    /// Claim a New pipeline message under a lock and re-check it is still New with a
    /// real stage, so two engine runs never advance the same message at once.
    /// </summary>
    local procedure ClaimStage(MessageId: Guid; var IntegrationMessage: Record "Integration Message"): Boolean
    begin
        IntegrationMessage.LockTable();
        if not IntegrationMessage.Get(MessageId) then
            exit(false);
        if IntegrationMessage.Status <> IntegrationMessage.Status::New then
            exit(false);
        if IntegrationMessage."Current Stage" in ["Integration Stage"::None, "Integration Stage"::Completed] then
            exit(false);
        MessageMgt.MarkInProgress(IntegrationMessage);
        Commit();
        exit(true);
    end;

    local procedure RunStage(var IntegrationMessage: Record "Integration Message")
    var
        StageRunner: Codeunit "Integration Stage Runner";
        ErrorText: Text;
    begin
        if StageRunner.Run(IntegrationMessage) then begin
            AdvanceCursor(IntegrationMessage);
            exit;
        end;

        ErrorText := GetLastErrorText();
        FailStage(IntegrationMessage, ErrorText);
    end;

    local procedure AdvanceCursor(var IntegrationMessage: Record "Integration Message")
    var
        Stage: Interface IIntegrationStage;
        NextStage: Enum "Integration Stage";
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        // A stage may have parked the message Awaiting Reply mid-pipeline; only
        // advance when it is still In Progress from this cycle.
        if IntegrationMessage.Status <> IntegrationMessage.Status::"In Progress" then
            exit;

        Stage := IntegrationMessage."Current Stage";
        NextStage := Stage.GetNextStage();

        if NextStage = NextStage::Completed then begin
            IntegrationMessage."Current Stage" := NextStage;
            MessageMgt.MarkResolved(IntegrationMessage);
            Commit();
            Telemetry.LogSucceeded(IntegrationMessage);
            exit;
        end;

        // Move the cursor on and re-queue for the next cycle. Each stage advance is
        // its own committed step, so progress is durable between stages.
        IntegrationMessage."Current Stage" := NextStage;
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        IntegrationMessage.Modify(true);
        Commit();
        Telemetry.LogStageAdvanced(IntegrationMessage);
    end;

    local procedure FailStage(var IntegrationMessage: Record "Integration Message"; ErrorText: Text)
    var
        ErrorHandler: Codeunit "Integration Error Handler";
    begin
        // Capture leaves Current Stage untouched, so retrying re-runs only the
        // failed stage; the earlier stages are not re-executed.
        ErrorHandler.Capture(IntegrationMessage, ErrorText);
    end;
}
