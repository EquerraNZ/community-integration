codeunit 73298434 "Subs-Sales Shipment"
{
    // Single-purpose, thin subscriber for posted sales shipments. No inline business
    // logic: it exits early on every precondition and delegates to the despatch
    // management codeunit. Subscribing to the table insert (rather than the posting
    // codeunit's wide event) keeps the signature stable.

    [EventSubscriber(ObjectType::Table, Database::"Sales Shipment Header", 'OnAfterInsertEvent', '', false, false)]
    local procedure SalesShipmentHeader_OnAfterInsertEvent(var Rec: Record "Sales Shipment Header"; RunTrigger: Boolean)
    var
        DespatchNotificationMgt: Codeunit "Despatch Notification Mgt.";
    begin
        if Rec.IsTemporary() then
            exit;
        if Session.CurrentExecutionMode <> ExecutionMode::Standard then
            exit;
        DespatchNotificationMgt.NotifyDespatch(Rec);
    end;
}
