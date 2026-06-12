page 73298450 "WMS Setup"
{
    ApplicationArea = All;
    Caption = 'WMS Setup';
    PageType = Card;
    SourceTable = "WMS Setup";
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the warehouse location used for fulfilment requests.';
                }
                field("Shipping Method"; Rec."Shipping Method")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default shipping method sent to the WMS.';
                }
                field("SKU Source"; Rec."SKU Source")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Source code used for reverse SKU lookup in Integration SKU Mapping.';
                }
                field("Post Invoice"; Rec."Post Invoice")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether to also post the Sales Invoice when a shipment confirmation is processed.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;
}
