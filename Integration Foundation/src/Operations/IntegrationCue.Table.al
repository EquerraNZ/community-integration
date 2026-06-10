// The single-record source for the Activities cue. The counts of failed, in
// progress, and waiting work are FlowFields here, deliberately not columns on the
// message list: FlowFields on a list recompute per row and silently slow the whole
// page down. Computing them once on a cue card is the BC-idiomatic way to show "how
// much is failed / in progress / waiting" at a glance.
table 73298403 "Integration Cue"
{
    Caption = 'Integration Cue';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "Failed Count"; Integer)
        {
            Caption = 'Failed';
            FieldClass = FlowField;
            CalcFormula = count("Integration Message" where(Status = const(Failed)));
            Editable = false;
        }
        field(20; "In Progress Count"; Integer)
        {
            Caption = 'In Progress';
            FieldClass = FlowField;
            CalcFormula = count("Integration Message" where(Status = const("In Progress")));
            Editable = false;
        }
        field(30; "Awaiting Reply Count"; Integer)
        {
            Caption = 'Awaiting Reply';
            FieldClass = FlowField;
            CalcFormula = count("Integration Message" where(Status = const("Awaiting Reply")));
            Editable = false;
        }
        field(40; "New Count"; Integer)
        {
            Caption = 'New';
            FieldClass = FlowField;
            CalcFormula = count("Integration Message" where(Status = const(New)));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
