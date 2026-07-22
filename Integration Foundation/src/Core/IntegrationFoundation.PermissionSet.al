permissionset 73298460 "Int. Foundation"
{
    Assignable = true;
    Caption = 'Integration Foundation';

    // Every object the extension defines is granted here. New objects are added as
    // features land; the permission-set auditor gates this.
    Permissions =
        tabledata "Integration Message" = RIMD,
        tabledata "Integration Setup" = RIMD,
        tabledata "Integration SKU Mapping" = RIMD,
        tabledata "Integration Expected Subscr." = RIMD,
        codeunit "Integration Message Mgt." = X,
        codeunit "Integration Msg. Dispatcher" = X,
        codeunit "Integration Msg. Processor" = X,
        codeunit "Integration Unknown Handler" = X,
        codeunit "Integration Telemetry" = X,
        codeunit "Integration SKU Mgt." = X,
        codeunit "Integration Resolution Mgt." = X,
        codeunit "Integration JSON Helper" = X,
        codeunit "Webstore Order Handler" = X,
        codeunit "Integration Outbound Events" = X,
        codeunit "Fulfilment Request Mgt." = X,
        codeunit "Subs-Sales Release" = X,
        codeunit "WMS Shipment Handler" = X,
        codeunit "Despatch Notification Mgt." = X,
        codeunit "Subs-Sales Shipment" = X,
        codeunit "Subscription Health Monitor" = X,
        tabledata "Sales Header" = RIMD,
        tabledata "Sales Line" = RIMD,
        tabledata "Sales Shipment Header" = R,
        page "Integration Setup" = X,
        page "Integration Message API" = X,
        page "Integration SKU Mappings" = X,
        page "Integration Message List" = X,
        page "Integration Message Card" = X,
        page "Integration Expected Subs." = X;
}
