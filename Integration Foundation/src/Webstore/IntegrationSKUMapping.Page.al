page 73298420 "Integration SKU Mapping"
{
    ApplicationArea = All;
    Caption = 'Integration SKU Mapping';
    PageType = List;
    SourceTable = "Integration SKU Mapping";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Source; Rec.Source)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the external system source (e.g. WEBSTORE).';
                }
                field("External SKU"; Rec."External SKU")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the SKU as the external system knows it.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the BC Item No. this external SKU maps to.';
                }
            }
        }
    }
}
