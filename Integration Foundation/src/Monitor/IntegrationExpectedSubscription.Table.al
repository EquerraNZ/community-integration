table 73298403 "Integration Expected Subscr."
{
    Caption = 'Integration Expected Subscription';
    DataClassification = SystemMetadata;
    LookupPageId = "Integration Expected Subs.";
    DrillDownPageId = "Integration Expected Subs.";

    fields
    {
        field(1; "Event Name"; Text[100])
        {
            Caption = 'Event Name';
            DataClassification = SystemMetadata;
            NotBlank = true;
        }
        field(2; "Notification URL"; Text[250])
        {
            Caption = 'Notification URL';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Event Name", "Notification URL") { Clustered = true; }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Event Name", "Notification URL") { }
    }
}
