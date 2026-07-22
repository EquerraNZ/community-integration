table 73298402 "Integration Setup"
{
    Caption = 'Integration Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "Webstore Customer No."; Code[20])
        {
            Caption = 'Webstore Customer No.';
            DataClassification = CustomerContent;
            TableRelation = Customer."No.";
        }
        field(11; "Default Location Code"; Code[10])
        {
            Caption = 'Default Location Code';
            DataClassification = CustomerContent;
            TableRelation = Location.Code;
        }
        field(12; "Post Invoice On Shipment"; Boolean)
        {
            Caption = 'Post Invoice On Shipment';
            DataClassification = CustomerContent;
        }
        field(13; "Default Shipment Method Code"; Code[10])
        {
            Caption = 'Default Shipment Method';
            DataClassification = CustomerContent;
            TableRelation = "Shipment Method".Code;
        }
        field(14; "Despatch Status"; Text[20])
        {
            Caption = 'Despatch Status';
            DataClassification = SystemMetadata;
            InitValue = 'Despatched';
        }
        field(15; "Max Retry Count"; Integer)
        {
            Caption = 'Max Retry Count';
            DataClassification = SystemMetadata;
            InitValue = 3;
            MinValue = 0;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    /// <summary>Ensure the singleton exists and load it into Rec.</summary>
    procedure GetSetup()
    begin
        Rec.Reset();
        if Rec.Get() then
            exit;
        Rec.Init();
        Rec."Primary Key" := '';
        Rec.Insert(true);
    end;
}
