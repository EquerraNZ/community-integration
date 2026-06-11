// Best practice: deduplicate on the caller's stable idempotency key BEFORE staging,
// backed by a unique key. A replay returns the prior result instead of being processed
// again. The internal Message ID is never the dedup key, because it is freshly generated
// per insert and so could never match a repeat.

table 50140 "Integration Message"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Message ID"; Guid) { Caption = 'Message ID'; }
        field(2; "Document No."; Text[50]) { Caption = 'Document No.'; }
        field(3; "Type"; Enum "Integration Message Type") { Caption = 'Type'; }
        field(4; Status; Enum "Integration Message Status") { Caption = 'Status'; }
        field(5; "Request Content"; Blob) { Caption = 'Request Content'; }
        field(6; "Response Content"; Blob) { Caption = 'Response Content'; }
        // The caller-controlled stable id. This, not Message ID, is what dedup keys on.
        field(7; "Idempotency Key"; Text[50]) { Caption = 'Idempotency Key'; }
        field(8; "Error Content"; Blob) { Caption = 'Error Content'; }
        field(9; "Error Code"; Code[20]) { Caption = 'Error Code'; }
        field(10; "Correlation ID"; Guid) { Caption = 'Correlation ID'; }
        field(11; "Parent Message ID"; Guid) { Caption = 'Parent Message ID'; }
    }

    keys
    {
        key(PK; "Message ID") { Clustered = true; }
        key(DocumentNo; "Document No.") { }
        // UNIQUE idempotency key: a second concurrent insert of the same delivery fails at
        // the database, so dedup holds even under a race, not only on the explicit lookup.
        key(Idempotency; "Idempotency Key") { Unique = true; }
        key(CorrelationID; "Correlation ID") { }
    }
}

codeunit 50141 "Inbound Dedup"
{
    procedure Stage(IdempotencyKey: Text[50]; MsgType: Enum "Integration Message Type"; Payload: Text): Guid
    var
        Existing: Record "Integration Message";
        IntegrationMessage: Record "Integration Message";
    begin
        // The idempotency lookup: a single indexed read on the unique key.
        Existing.SetRange("Idempotency Key", IdempotencyKey);
        if Existing.FindFirst() then begin
            case Existing.Status of
                Existing.Status::Completed:
                    // Already processed. Return the prior result; do NOT do the work again.
                    exit(Existing."Message ID");
                Existing.Status::"In Progress":
                    // A run is already handling this exact message. Reject the
                    // second one rather than process the same message concurrently.
                    Error('Message with idempotency key %1 is already in progress', IdempotencyKey);
            end;
            // Any other prior state (for example Failed): return the existing row so the
            // resolution flow handles it, instead of minting a duplicate.
            exit(Existing."Message ID");
        end;

        // No prior message exists: stage a genuinely new one.
        IntegrationMessage.Init();
        IntegrationMessage."Message ID" := CreateGuid(); // internal id, never the dedup key
        IntegrationMessage."Idempotency Key" := IdempotencyKey;
        IntegrationMessage.Type := MsgType;
        IntegrationMessage."Correlation ID" := CreateGuid();
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        IntegrationMessage.SetRequestContent(Payload);
        // If a concurrent request slipped past the lookup, the unique key makes THIS Insert
        // fail rather than create a duplicate. Either way, the side effect runs at most once.
        IntegrationMessage.Insert(true);
        exit(IntegrationMessage."Message ID");
    end;
}
