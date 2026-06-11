// Good: process inline by default, defer only when Job Queue Category Code is set.
// The API page processes the message immediately after insert unless the caller
// explicitly requested deferral.

page 50100 "Integration Message API"
{
    PageType = API;
    // ...
    SourceTable = "Integration Message";

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec."Message ID" := CreateGuid();
        Rec."Correlation ID" := CreateGuid();
        Rec.Status := Rec.Status::New;
        Rec."Created At" := CurrentDateTime();
        exit(true);
    end;

    trigger OnAfterInsertRecord(var Rec: Record "Integration Message")
    var
        InboundProcessor: Codeunit "Inbound Msg. Processor";
    begin
        // Process inline at runtime unless deferred to Job Queue.
        if Rec."Job Queue Category Code" = '' then
            InboundProcessor.RunInline(Rec);
    end;
}

// The processor exposes RunInline for the immediate path and uses a Job Queue
// filter for the deferred path.
codeunit 50101 "Inbound Msg. Processor"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        // Job Queue path: only picks up messages explicitly deferred.
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        IntegrationMessage.SetFilter("Job Queue Category Code", '<>%1', '');
        if IntegrationMessage.FindSet() then
            repeat
                ProcessMessage(IntegrationMessage);
            until IntegrationMessage.Next() = 0;
    end;

    procedure RunInline(var IntegrationMessage: Record "Integration Message")
    begin
        ProcessMessage(IntegrationMessage);
    end;

    procedure ProcessMessage(var IntegrationMessage: Record "Integration Message")
    begin
        // ... dispatch by Type, mark Completed or Failed.
    end;
}
