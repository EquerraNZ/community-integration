// The Integration Message is the single staging record every pattern is built on.
// Inbound and outbound, single-handler and multi-stage, fast and long-running: all
// of them are rows in this one table. Keeping one spine means one place to look
// when something is stuck, one resolution screen, and one idempotency guarantee.
//
// The table holds data only. All behaviour (staging, status transitions, payload
// read/write, spawning child work, logging) lives in codeunit "Integration Message
// Mgt.", which is the single data-access facade for this record. Keeping the table
// thin keeps the state machine in one reviewable place.
//
// This file grows pattern by pattern: Pattern 1 defines the dispatch spine here;
// later patterns add the error fields (3), the status URL (4), the stage cursor
// (5), and the assignee (6).
table 73298400 "Integration Message"
{
    Caption = 'Integration Message';
    DataClassification = CustomerContent;
    DrillDownPageId = "Integration Messages";
    LookupPageId = "Integration Messages";

    fields
    {
        field(1; "Message ID"; Guid)
        {
            Caption = 'Message ID';
            DataClassification = SystemMetadata;
            // System-assigned, never reused, and never the external dedup key. A
            // retry re-runs the same Message ID; the idempotency check (keyed on
            // External Reference + Type) is what stops a duplicate side effect.
        }
        field(2; Direction; Enum "Integration Direction")
        {
            Caption = 'Direction';
            DataClassification = SystemMetadata;
        }
        field(3; Type; Enum "Integration Type")
        {
            Caption = 'Type';
            DataClassification = SystemMetadata;
            // Drives dispatch. The enum implements IIntegrationHandler, so the
            // dispatcher routes by this value with no CASE statement.
        }
        field(4; Status; Enum "Integration Status")
        {
            Caption = 'Status';
            DataClassification = SystemMetadata;
            // The only field the Job Queue processors filter on. Editable on the
            // card during manual recovery (Failed -> New to retry).
        }
        field(5; "External Reference"; Text[250])
        {
            Caption = 'External Reference';
            DataClassification = CustomerContent;
            // The stable id from the source system. Half of the idempotency key.
            // Duplicates from the source are a guarantee, not an edge case.
        }
        field(6; "Correlation ID"; Code[40])
        {
            Caption = 'Correlation ID';
            DataClassification = SystemMetadata;
            // One trace id carried across BC, queues, and external systems. Set
            // once at the entry point. For a long-running flow the request row and
            // the reply row share this value; that is how they are matched.
        }
        field(7; "Parent Message ID"; Guid)
        {
            Caption = 'Parent Message ID';
            DataClassification = SystemMetadata;
            // Span parent. A pipeline stage that spawns work, and a reply matched
            // to its request, both point back here, giving a traceable tree.
        }
        field(8; "Document No."; Code[40])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
            // Optional BC document anchor (sales order, shipment) the message
            // relates to. Left blank when the message is not document-bound.
        }
        field(9; "Source System"; Text[100])
        {
            Caption = 'Source System';
            DataClassification = CustomerContent;
        }
        field(10; Request; Blob)
        {
            Caption = 'Request';
            DataClassification = CustomerContent;
            // The inbound/outbound payload as received. Read and written through
            // the Mgt facade, never directly, so encoding stays consistent.
        }
        field(11; Response; Blob)
        {
            Caption = 'Response';
            DataClassification = CustomerContent;
            // The result of processing. Replayed verbatim to a duplicate caller so
            // a retry is indistinguishable from the first attempt.
        }
        field(20; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(21; "Resolved At"; DateTime)
        {
            Caption = 'Resolved At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        // --- Pattern 3: durable error capture and out-of-band classification ---
        field(30; "Error Message"; Blob)
        {
            Caption = 'Error Message';
            DataClassification = CustomerContent;
            // The last error captured durably when a handler or stage failed. A
            // blob because error text plus call stack can exceed a Text field.
        }
        field(31; "Error Class"; Enum "Integration Error Class")
        {
            Caption = 'Error Class';
            DataClassification = SystemMetadata;
            // Assigned out of band by the classifier, never inline at failure time.
        }
        field(32; Classified; Boolean)
        {
            Caption = 'Classified';
            DataClassification = SystemMetadata;
            // The gate the classifier job filters on: Failed and not yet Classified.
        }
        field(33; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            DataClassification = SystemMetadata;
            // Retry state lives on the record, not in code. Retrying re-runs the
            // same Message ID; the idempotency check stops a duplicate side effect.
        }
        field(34; "Failed At"; DateTime)
        {
            Caption = 'Failed At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        // --- Pattern 4: delayed reply -------------------------------------------
        field(40; "Status URL"; Text[2048])
        {
            Caption = 'Status URL';
            DataClassification = CustomerContent;
            ExtendedDatatype = URL;
            // For a long-running flow the external system answers later. The
            // request parks here with the URL to poll (or the reference the reply
            // will carry), and the reply is matched back by Correlation ID.
        }
        // --- Pattern 5: durable staged pipeline ---------------------------------
        field(50; "Current Stage"; Enum "Integration Stage")
        {
            Caption = 'Current Stage';
            DataClassification = SystemMetadata;
            // The pipeline cursor. None means this is a single-handler message (the
            // dispatcher owns it); any other value means the pipeline engine owns
            // it and this is the stage to run next. Status is the cursor, so there
            // is no new row per stage; a failed stage is retried by leaving Current
            // Stage where it is and flipping Status back to New.
        }
        // --- Pattern 6: operations and manual recovery --------------------------
        field(60; "Assigned To User ID"; Code[50])
        {
            Caption = 'Assigned To User ID';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
            ValidateTableRelation = false;
            // Who owns this stuck message. Reassign hands it to another user without
            // changing its status, so triage and fixing can be split across a team.
        }
    }

    keys
    {
        key(PK; "Message ID")
        {
            Clustered = true;
        }
        // The work key the Job Queue processors set before scanning: status first
        // (the selective filter), then direction, then arrival order so the oldest
        // waiting work is picked up first.
        key(Work; Status, Direction, SystemCreatedAt)
        {
        }
        // The idempotency key. A lookup on (External Reference, Type) decides
        // whether an inbound item has been seen before.
        key(Idempotency; "External Reference", Type)
        {
        }
        // Reply matching for long-running flows walks this key.
        key(Correlation; "Correlation ID")
        {
        }
        // Walking a parent's spawned children.
        key(Parent; "Parent Message ID")
        {
        }
        // The classifier job filters on unclassified failures; this key keeps that
        // scan off the full table.
        key(Classification; Classified, Status)
        {
        }
        // The pipeline engine filters on stage and status; this key keeps that
        // scan off the full table.
        key(Pipeline; "Current Stage", Status)
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Message ID", Type, Status, "External Reference")
        {
        }
        fieldgroup(Brick; Type, Status, "External Reference", "Correlation ID")
        {
        }
    }

    trigger OnInsert()
    begin
        // Guarantee valid keys no matter how the row was created (the Mgt facade,
        // a consuming app, or a direct API insert). Trace identity is part of the
        // record's identity, so a row is never without a Correlation ID.
        if IsNullGuid("Message ID") then
            "Message ID" := CreateGuid();
        if "Correlation ID" = '' then
            "Correlation ID" := CopyStr(Format(CreateGuid(), 0, 4), 1, MaxStrLen("Correlation ID"));
    end;
}
