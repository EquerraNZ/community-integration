table 73298420 "Integration SKU Mapping"
{
    Caption = 'Integration SKU Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "Integration SKU Mapping";
    DrillDownPageId = "Integration SKU Mapping";

    fields
    {
        field(1; Source; Code[20])
        {
            Caption = 'Source';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(2; "External SKU"; Code[50])
        {
            Caption = 'External SKU';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            NotBlank = true;
            TableRelation = Item."No.";
        }
    }

    keys
    {
        key(PK; Source, "External SKU")
        {
            Clustered = true;
        }
    }
}
