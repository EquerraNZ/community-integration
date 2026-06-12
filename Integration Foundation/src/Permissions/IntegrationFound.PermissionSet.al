permissionset 73298480 "Integration Found."
{
    Caption = 'Integration Foundation';
    Assignable = true;

    Permissions =
        table "Integration Message" = RIMD,
        table "Integration SKU Mapping" = RIMD,
        table "Webstore Setup" = RIMD,
        table "WMS Setup" = RIMD,
        codeunit "Integration Msg. Process" = X,
        codeunit "Integration Msg. Retry" = X,
        codeunit "Integration Msg. Stage" = X,
        codeunit "Webstore Order Processor" = X,
        codeunit "Webstore Ship. Notify Proc." = X,
        codeunit "Webstore Shipment Notify" = X,
        codeunit "Fulfilment Req. Processor" = X,
        codeunit "Fulfilment Request Mgt." = X,
        codeunit "Integration Events" = X,
        codeunit "Shipment Confirm. Proc." = X,
        page "Integration Messages API" = X,
        page "Integration Messages" = X,
        page "Integration Message Card" = X,
        page "Integration SKU Mapping" = X,
        page "Webstore Setup" = X,
        page "WMS Setup" = X;
}
