page 73298442 "Integration SKU Mappings"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Integration SKU Mapping";
    Caption = 'Integration SKU Mappings';

    layout
    {
        area(Content)
        {
            repeater(Mappings)
            {
                field(SKU; Rec.SKU)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the catalogue SKU used by the external systems.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central item the SKU maps to.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item variant the SKU maps to, if any.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit of measure used on lines created from this SKU.';
                }
                field("Item Description"; Rec."Item Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the description of the mapped item.';
                }
            }
        }
    }
}
