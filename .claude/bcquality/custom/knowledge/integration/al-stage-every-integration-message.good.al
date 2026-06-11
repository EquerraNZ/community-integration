// Best practice: a single staging table, a thin acceptance endpoint, and a
// background processor. The endpoint only validates and stages; it never posts
// and never calls the source system back. The Job Queue codeunit does the real
// work later, decoupled from the caller and from the remote system's uptime.

// --- The spine: one staging table for every integration message ---
table 50100 "Integration Message"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Message ID"; Guid) { Caption = 'Message ID'; }
        field(2; "Document No."; Text[50]) { Caption = 'Document No.'; }
        // Type drives the dispatcher below. A new message kind is a new enum value
        // implementing IIntegrationMessageHandler, not a new published API page.
        field(3; "Type"; Enum "Integration Message Type") { Caption = 'Type'; }
        field(4; Status; Enum "Integration Message Status") { Caption = 'Status'; }
        field(5; "Request Content"; Blob) { Caption = 'Request Content'; }
        field(6; "Response Content"; Blob) { Caption = 'Response Content'; }
        // The stable dedup key. A replayed request carries the same Idempotency Key,
        // so the unique index rejects the duplicate at the database level.
        field(7; "Idempotency Key"; Text[50]) { Caption = 'Idempotency Key'; }
        field(8; "Error Content"; Blob) { Caption = 'Error Content'; }
        field(9; "Error Code"; Code[20]) { Caption = 'Error Code'; }
        // Trace ID across BC and external systems. Minted once at the entry point,
        // carried unchanged on every staged message and outbound call.
        field(10; "Correlation ID"; Guid) { Caption = 'Correlation ID'; }
        // Span parent for staged pipelines: links child stages back to the root message.
        field(11; "Parent Message ID"; Guid) { Caption = 'Parent Message ID'; }
    }

    keys
    {
        key(PK; "Message ID") { Clustered = true; }
        key(DocumentNo; "Document No.") { }
        // The idempotency key: detect a replayed message at insert time.
        key(Idempotency; "Idempotency Key") { Unique = true; }
        key(CorrelationID; "Correlation ID") { }
    }
}

// --- Phase one: acceptance. Validate, stage, return. No posting here. ---
page 50100 "Integration Message API"
{
    PageType = API;
    APIPublisher = 'contoso';
    APIGroup = 'integration';
    APIVersion = 'v1.0';
    EntityName = 'integrationMessage';
    EntitySetName = 'integrationMessages';
    SourceTable = "Integration Message";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(idempotencyKey; Rec."Idempotency Key") { }
                field(type; Rec.Type) { }
                field(documentNo; Rec."Document No.") { }
                field(requestContent; Rec."Request Content") { }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        // The only work the endpoint does: stamp identity and mark the row New.
        // Everything expensive happens later, in the Job Queue processor.
        Rec."Message ID" := CreateGuid();
        Rec."Correlation ID" := CreateGuid();
        Rec.Status := Rec.Status::New;
    end;
}

// --- Phase two: processing. Runs as a Job Queue entry, reads staged rows. ---
codeunit 50101 "Inbound Message Processor"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        // Read by Status. The caller is long gone.
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        if IntegrationMessage.FindSet() then
            repeat
                Dispatch(IntegrationMessage);
            until IntegrationMessage.Next() = 0;
    end;

    // The Type enum routes to the right handler via its interface implementation.
    local procedure Dispatch(var IntegrationMessage: Record "Integration Message")
    begin
        // ... resolve a handler by IntegrationMessage.Type and run it; on
        // success set Status::Completed, on failure stamp Error Content and
        // Error Code so the row stays auditable and re-runnable.
    end;
}
