codeunit 73298431 "Fulfilment Request Mgt."
{
    // Builds the fulfilment DTO for a released Webstore order, stages the outbound
    // correlation parent, and raises the external business event. Holds the logic so
    // the release subscriber stays thin. Makes no external call.

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        SKUMgt: Codeunit "Integration SKU Mgt.";
        OutboundEvents: Codeunit "Integration Outbound Events";
        JsonHelper: Codeunit "Integration JSON Helper";
        FulfilmentTypeCodeTok: Label 'FulfilmentRequest', Locked = true;
        DefaultShippingTok: Label 'Standard', Locked = true;

    /// <summary>
    /// For a released Webstore order, stage the outbound parent and raise
    /// OnSalesOrderReleased_v1. A no-op for non-Webstore orders or orders without an
    /// external document number.
    /// </summary>
    procedure RequestFulfilment(var SalesHeader: Record "Sales Header")
    var
        IntegrationSetup: Record "Integration Setup";
        Reference: Code[35];
        CorrelationId: Code[40];
        PayloadText: Text;
        StagedMessageId: Guid;
    begin
        if not IntegrationSetup.Get() then
            exit;
        if IntegrationSetup."Webstore Customer No." = '' then
            exit;
        if SalesHeader."Sell-to Customer No." <> IntegrationSetup."Webstore Customer No." then
            exit;

        Reference := SalesHeader."External Document No.";
        if Reference = '' then
            exit;
        CorrelationId := CopyStr(Reference, 1, MaxStrLen(CorrelationId));

        PayloadText := BuildFulfilmentJson(SalesHeader, Reference, CorrelationId);
        StagedMessageId := MessageMgt.StageOutbound(FulfilmentTypeCodeTok, CopyStr(Reference, 1, 100), CorrelationId, SalesHeader."No.", PayloadText);
        // The event carries identifiers only; the full PayloadText is on the staged
        // outbound message above (event args are capped at 250 chars).
        OutboundEvents.OnSalesOrderReleased_v1(Reference, SalesHeader."No.", CorrelationId);
        MessageMgt.LogEventFired(StagedMessageId);
    end;

    /// <summary>
    /// Build the fulfilment DTO JSON: identifiers, ship-to, and one line per item
    /// reverse-mapped to its source SKU. Public so it can be asserted in tests.
    /// </summary>
    procedure BuildFulfilmentJson(var SalesHeader: Record "Sales Header"; Reference: Code[35]; CorrelationId: Code[40]): Text
    var
        SalesLine: Record "Sales Line";
        Root: JsonObject;
        ShipTo: JsonObject;
        Lines: JsonArray;
        LineObj: JsonObject;
        SKU: Code[20];
        PayloadText: Text;
    begin
        Root.Add('reference', Reference);
        Root.Add('bcOrderNo', SalesHeader."No.");
        Root.Add('correlationId', CorrelationId);

        ShipTo.Add('name', SalesHeader."Ship-to Name");
        ShipTo.Add('line1', SalesHeader."Ship-to Address");
        ShipTo.Add('city', SalesHeader."Ship-to City");
        ShipTo.Add('postcode', SalesHeader."Ship-to Post Code");
        ShipTo.Add('country', SalesHeader."Ship-to Country/Region Code");
        ShipTo.Add('phone', SalesHeader."Ship-to Phone No.");
        Root.Add('shipTo', ShipTo);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        if SalesLine.FindSet() then
            repeat
                Clear(LineObj);
                if SKUMgt.TryGetSKU(SalesLine."No.", SalesLine."Variant Code", SKU) then
                    LineObj.Add('sku', SKU)
                else
                    LineObj.Add('sku', SalesLine."No."); // no reverse mapping: send the item no so the miss is visible at the WMS
                LineObj.Add('quantity', SalesLine.Quantity);
                Lines.Add(LineObj);
            until SalesLine.Next() = 0;
        Root.Add('lines', Lines);

        Root.Add('shippingMethod', GetShippingMethod(SalesHeader));
        Root.Add('requestedAt', JsonHelper.IsoNow());

        Root.WriteTo(PayloadText);
        exit(PayloadText);
    end;

    local procedure GetShippingMethod(SalesHeader: Record "Sales Header"): Text
    begin
        if SalesHeader."Shipment Method Code" <> '' then
            exit(SalesHeader."Shipment Method Code");
        exit(DefaultShippingTok);
    end;
}
