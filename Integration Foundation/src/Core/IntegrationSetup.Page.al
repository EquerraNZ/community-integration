page 73298441 "Integration Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Integration Setup";
    Caption = 'Integration Setup';
    InsertAllowed = false;
    DeleteAllowed = false;
    AboutTitle = 'About Integration Setup';
    AboutText = 'Configure the shared Webstore customer, default location, invoice toggle, and retry policy used by every integration on the foundation.';

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Webstore Customer No."; Rec."Webstore Customer No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the dedicated Business Central customer that every Webstore order is created against.';
                }
                field("Default Location Code"; Rec."Default Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location used on orders and shipments created by the integration.';
                }
                field("Default Shipment Method Code"; Rec."Default Shipment Method Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the shipment method applied to orders created by the integration.';
                }
            }
            group(Shipment)
            {
                Caption = 'Shipment and despatch';

                field("Post Invoice On Shipment"; Rec."Post Invoice On Shipment")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the shipment confirmation also posts the sales invoice.';
                }
                field("Despatch Status"; Rec."Despatch Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the storefront order status set when an order is despatched.';
                }
            }
            group(Retry)
            {
                Caption = 'Retry policy';

                field("Max Retry Count"; Rec."Max Retry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many times a transient failure is re-queued before the message is left Failed for manual resolution.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;
}
