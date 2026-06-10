// The per-message audit trail. Append-only entries record the lifecycle milestones
// and, most importantly, every manual recovery action with the user and time, so a
// stuck message that a person inspected, retried, resolved, or reassigned carries a
// durable record of what happened and why. This is the same idea the standard
// E-Document experience keeps for inbound documents.
table 73298402 "Integration Message Log"
{
    Caption = 'Integration Message Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Message ID"; Guid)
        {
            Caption = 'Message ID';
            DataClassification = SystemMetadata;
            TableRelation = "Integration Message"."Message ID";
        }
        field(2; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(10; Event; Enum "Integration Log Event")
        {
            Caption = 'Event';
            DataClassification = SystemMetadata;
        }
        field(20; Description; Text[250])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(30; "Logged At"; DateTime)
        {
            Caption = 'Logged At';
            DataClassification = SystemMetadata;
        }
        field(31; "Logged By"; Code[50])
        {
            Caption = 'Logged By';
            DataClassification = EndUserIdentifiableInformation;
        }
    }

    keys
    {
        key(PK; "Message ID", "Entry No.")
        {
            Clustered = true;
        }
        key(ByEntry; "Entry No.")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(Brick; "Logged At", Event, Description, "Logged By")
        {
        }
    }
}
