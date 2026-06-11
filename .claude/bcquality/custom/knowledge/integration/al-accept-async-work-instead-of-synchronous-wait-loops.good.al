// Best practice: accept the work, STAGE it, return 202 Accepted with a status URL, and
// free the request thread immediately. A background processor finishes the slow work;
// the caller polls the status URL and watches Status advance. No thread is ever pinned
// to a downstream system's latency.

codeunit 50120 "Inbound Intake"
{
    // Called from the API insert trigger / webhook receiver. It returns the URL the HTTP
    // layer puts in the Location header alongside a 202 Accepted.
    procedure Accept(Payload: Text; IdempotencyKey: Text[50]) StatusUrl: Text
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.Init();
        IntegrationMessage."Message ID" := CreateGuid();
        IntegrationMessage."Idempotency Key" := IdempotencyKey;
        // New means "accepted, not yet processed". The background processor picks it up;
        // the caller sees it move to In Progress, then Completed or Failed.
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        IntegrationMessage."Correlation ID" := CreateGuid();
        IntegrationMessage.SetRequestContent(Payload);
        // The ONLY expensive thing on the request path is this Insert. The moment it
        // returns, the request thread is free to serve the next caller.
        IntegrationMessage.Insert(true);

        // Point the caller at the staged row. The HTTP layer maps this to
        // 202 Accepted + a Location header; the caller polls it for completion.
        exit(StrSubstNo('/api/contoso/integration/v1.0/integrationMessages(%1)', IntegrationMessage."Message ID"));
    end;
}

// Read-only status endpoint the caller polls. No blocking, no Sleep, no remote call:
// it just projects the current state of the staged row.
page 50121 "Integration Message Status"
{
    PageType = API;
    APIPublisher = 'contoso';
    APIGroup = 'integration';
    APIVersion = 'v1.0';
    EntityName = 'integrationMessage';
    EntitySetName = 'integrationMessages';
    SourceTable = "Integration Message";
    Editable = false; // a status endpoint never mutates; it only reports

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(id; Rec."Message ID") { }
                // The field the caller polls. New -> In Progress -> Completed / Failed.
                field(status; Rec.Status) { }
                field(errorCode; Rec."Error Code") { } // populated only on Failed
            }
        }
    }
}

codeunit 50122 "Inbound Processor"
{
    TableNo = "Job Queue Entry";

    // Runs in the background, NOT on the request thread. This is where the slow work lives,
    // so the caller's connection is never held open for it.
    trigger OnRun()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        if IntegrationMessage.FindSet() then
            repeat
                IntegrationMessage.Status := IntegrationMessage.Status::"In Progress";
                IntegrationMessage.Modify(true);
                Commit(); // make In Progress visible to a polling caller at once
                Process(IntegrationMessage); // the slow part: runs here, off the request path
            until IntegrationMessage.Next() = 0;
    end;

    local procedure Process(var IntegrationMessage: Record "Integration Message")
    begin
        // ... do the real work; on success set Status::Completed and store the response content,
        // on failure set Status::Failed and stamp Error Code + Error Content. The caller's next poll sees it.
    end;
}
