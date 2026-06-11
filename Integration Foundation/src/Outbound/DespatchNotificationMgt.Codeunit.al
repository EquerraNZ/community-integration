codeunit 73298433 "Despatch Notification Mgt."
{
    // Raises the despatch notification once per Webstore order after its shipment
    // posts. Idempotent on the order number so a second (partial) shipment does not
    // notify twice. Holds the logic so the shipment subscriber stays thin. Makes no
    // external call.

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        OutboundEvents: Codeunit "Integration Outbound Events";
        JsonHelper: Codeunit "Integration JSON Helper";
        DespatchTypeCodeTok: Label 'DespatchNotification', Locked = true;

    /// <summary>
    /// For a posted shipment of a Webstore order, stage the outbound notification and
    /// raise OnShipmentConfirmed_v1, at most once per order. A no-op for non-Webstore
    /// shipments, orders without a storefront order number, or an already-notified
    /// order.
    /// </summary>
    procedure NotifyDespatch(var SalesShipmentHeader: Record "Sales Shipment Header")
    var
        IntegrationSetup: Record "Integration Setup";
        OrderNo: Code[35];
        BcOrderNo: Code[20];
        CorrelationId: Code[40];
        DespatchedAt: Text;
        PayloadText: Text;
        StagedMessageId: Guid;
    begin
        if not IntegrationSetup.Get() then
            exit;
        if IntegrationSetup."Webstore Customer No." = '' then
            exit;
        if SalesShipmentHeader."Sell-to Customer No." <> IntegrationSetup."Webstore Customer No." then
            exit;

        OrderNo := SalesShipmentHeader."External Document No.";
        if OrderNo = '' then
            exit;

        // Idempotent: notify at most once per order, even across partial shipments.
        if MessageMgt.OutboundExists(DespatchTypeCodeTok, OrderNo) then
            exit;

        BcOrderNo := SalesShipmentHeader."Order No.";
        CorrelationId := CopyStr(OrderNo, 1, MaxStrLen(CorrelationId));
        DespatchedAt := JsonHelper.IsoNow();
        PayloadText := BuildDespatchJson(OrderNo, BcOrderNo, CorrelationId, DespatchedAt);

        StagedMessageId := MessageMgt.StageOutbound(DespatchTypeCodeTok, CopyStr(OrderNo, 1, 100), CorrelationId, BcOrderNo, PayloadText);
        OutboundEvents.OnShipmentConfirmed_v1(OrderNo, BcOrderNo, CorrelationId, DespatchedAt);
        MessageMgt.LogEventFired(StagedMessageId);
    end;

    local procedure BuildDespatchJson(OrderNo: Code[35]; BcOrderNo: Code[20]; CorrelationId: Code[40]; DespatchedAt: Text): Text
    var
        Root: JsonObject;
        PayloadText: Text;
    begin
        Root.Add('orderNo', OrderNo);
        Root.Add('bcOrderNo', BcOrderNo);
        Root.Add('correlationId', CorrelationId);
        Root.Add('despatchedAt', DespatchedAt);
        Root.WriteTo(PayloadText);
        exit(PayloadText);
    end;
}
