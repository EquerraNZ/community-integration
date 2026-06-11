table 73298401 "Integration SKU Mapping"
{
    Caption = 'Integration SKU Mapping';
    DataClassification = SystemMetadata;
    LookupPageId = "Integration SKU Mappings";
    DrillDownPageId = "Integration SKU Mappings";

    fields
    {
        field(1; SKU; Code[20])
        {
            Caption = 'SKU';
            DataClassification = SystemMetadata;
            NotBlank = true;
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = SystemMetadata;
            TableRelation = Item."No.";
            NotBlank = true;
        }
        field(3; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            DataClassification = SystemMetadata;
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(4; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure';
            DataClassification = SystemMetadata;
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(5; "Item Description"; Text[100])
        {
            Caption = 'Item Description';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = lookup(Item.Description where("No." = field("Item No.")));
        }
    }

    keys
    {
        key(PK; SKU) { Clustered = true; }
        // Reverse lookup (item to SKU) for outbound payloads: a single indexed read.
        key(ByItem; "Item No.", "Variant Code") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; SKU, "Item No.", "Variant Code") { }
        fieldgroup(Brick; SKU, "Item No.", "Item Description") { }
    }
}
