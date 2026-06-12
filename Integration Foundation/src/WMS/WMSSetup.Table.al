table 73298450 "WMS Setup"
{
    Caption = 'WMS Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            DataClassification = CustomerContent;
            TableRelation = Location.Code;
        }
        field(3; "Shipping Method"; Text[50])
        {
            Caption = 'Shipping Method';
            DataClassification = CustomerContent;
        }
        field(4; "SKU Source"; Code[20])
        {
            Caption = 'SKU Source';
            DataClassification = CustomerContent;
            InitValue = 'WMS';
        }
        field(5; "Post Invoice"; Boolean)
        {
            Caption = 'Post Invoice';
            DataClassification = CustomerContent;
            InitValue = false;
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
