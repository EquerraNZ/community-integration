// Bad: always deferring to Job Queue even when inline processing is appropriate.
// This adds latency (polling interval), requires Job Queue Entry configuration,
// and the caller never gets an immediate result.

page 50100 "Integration Message API"
{
    PageType = API;
    // ...
    SourceTable = "Integration Message";

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        // Only stages the message. Processing always happens later via Job Queue.
        Rec."Message ID" := CreateGuid();
        Rec."Correlation ID" := CreateGuid();
        Rec.Status := Rec.Status::New;
        Rec."Created At" := CurrentDateTime();
        exit(true);
    end;
    // No inline processing. The caller must poll or wait for the Job Queue.
}

// The processor runs on a schedule and picks up ALL new messages.
// There is no way to process a message immediately even when it could be.
codeunit 50101 "Inbound Msg. Processor"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        // Unconditionally deferred: every message waits for the next poll cycle.
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        if IntegrationMessage.FindSet() then
            repeat
                ProcessMessage(IntegrationMessage);
            until IntegrationMessage.Next() = 0;
    end;

    // ProcessMessage is local: it cannot be called from outside.
    local procedure ProcessMessage(var IntegrationMessage: Record "Integration Message")
    begin
        // ...
    end;
}
