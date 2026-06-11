codeunit 73298428 "WMS Shipment Handler" implements "IIntegrationMessageHandler"
{
    // Inbound business process 3 (long-running): post the warehouse shipment from a
    // WMS confirmation. Runs inside the dispatcher's per-message transaction with
    // commit suppressed, so a failure rolls back the post and the message can retry or
    // fail to resolution. Idempotency is the staging dedup on shipmentId. Makes no
    // external call; posting the shipment is what later fires the despatch event (007).

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        JsonHelper: Codeunit "Integration JSON Helper";
        SKUMgt: Codeunit "Integration SKU Mgt.";
        BadPayloadErr: Label 'The WMS shipment confirmation payload could not be parsed as JSON.';
        NoOrderErr: Label 'No open sales order was found for reference ''%1'' / bcOrderNo ''%2''.', Comment = '%1 = order number, %2 = bc order no';
        UnmappedSKUErr: Label 'SKU ''%1'' on shipment ''%2'' is not mapped to a Business Central item.', Comment = '%1 = SKU, %2 = shipment id';
        NothingToShipErr: Label 'The shipment confirmation ''%1'' has no shippable lines for order ''%2''.', Comment = '%1 = shipment id, %2 = order no';

    procedure HandleMessage(var IntegrationMessage: Record "Integration Message")
    var
        SalesHeader: Record "Sales Header";
        ConfirmationJson: JsonObject;
        Reference: Code[35];
        BcOrderNo: Code[20];
        ShipmentId: Text;
        TrackingNo: Text;
    begin
        if not JsonHelper.TryParse(IntegrationMessage.GetRequest(), ConfirmationJson) then
            Error(MessageMgt.CreatePermanentError(BadPayloadErr));

        Reference := CopyStr(JsonHelper.GetText(ConfirmationJson, 'reference'), 1, MaxStrLen(Reference));
        BcOrderNo := CopyStr(JsonHelper.GetText(ConfirmationJson, 'bcOrderNo'), 1, MaxStrLen(BcOrderNo));
        ShipmentId := JsonHelper.GetText(ConfirmationJson, 'shipmentId');
        TrackingNo := JsonHelper.GetText(ConfirmationJson, 'trackingNumber');

        if not FindOrder(BcOrderNo, Reference, SalesHeader) then
            Error(MessageMgt.CreatePermanentError(StrSubstNo(NoOrderErr, Reference, BcOrderNo)));

        ApplyTracking(SalesHeader, TrackingNo);
        ApplyShippedQuantities(SalesHeader, ConfirmationJson, ShipmentId);

        LinkCorrelationParent(IntegrationMessage, Reference);
        PostShipment(SalesHeader, IntegrationMessage, ShipmentId, TrackingNo);
    end;

    local procedure FindOrder(BcOrderNo: Code[20]; Reference: Code[35]; var SalesHeader: Record "Sales Header"): Boolean
    var
        IntegrationSetup: Record "Integration Setup";
    begin
        if BcOrderNo <> '' then
            if SalesHeader.Get(SalesHeader."Document Type"::Order, BcOrderNo) then
                exit(true);

        if Reference = '' then
            exit(false);
        if not IntegrationSetup.Get() then
            exit(false);
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("Sell-to Customer No.", IntegrationSetup."Webstore Customer No.");
        SalesHeader.SetRange("External Document No.", Reference);
        exit(SalesHeader.FindFirst());
    end;

    local procedure ApplyTracking(var SalesHeader: Record "Sales Header"; TrackingNo: Text)
    begin
        if TrackingNo = '' then
            exit;
        SalesHeader."Package Tracking No." := CopyStr(TrackingNo, 1, MaxStrLen(SalesHeader."Package Tracking No."));
        SalesHeader.Modify(true);
    end;

    local procedure ApplyShippedQuantities(SalesHeader: Record "Sales Header"; ConfirmationJson: JsonObject; ShipmentId: Text)
    var
        SalesLine: Record "Sales Line";
        SKUMapping: Record "Integration SKU Mapping";
        LinesArray: JsonArray;
        LineToken: JsonToken;
        LineJson: JsonObject;
        SKU: Code[20];
        ShippedQty: Decimal;
        AnyToShip: Boolean;
    begin
        // Start from zero: lines not named in the confirmation ship nothing.
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        if SalesLine.FindSet() then
            repeat
                SalesLine.Validate("Qty. to Ship", 0);
                SalesLine.Modify(true);
            until SalesLine.Next() = 0;

        if not JsonHelper.GetArray(ConfirmationJson, 'lines', LinesArray) then
            Error(MessageMgt.CreatePermanentError(StrSubstNo(NothingToShipErr, ShipmentId, SalesHeader."No.")));

        foreach LineToken in LinesArray do begin
            LineJson := LineToken.AsObject();
            SKU := CopyStr(JsonHelper.GetText(LineJson, 'sku'), 1, MaxStrLen(SKU));
            ShippedQty := JsonHelper.GetDecimal(LineJson, 'shippedQuantity');
            if ShippedQty <= 0 then
                continue;
            if not SKUMgt.TryGetMapping(SKU, SKUMapping) then
                Error(MessageMgt.CreatePermanentError(StrSubstNo(UnmappedSKUErr, SKU, ShipmentId)));

            if FindOrderLine(SalesHeader, SKUMapping."Item No.", SKUMapping."Variant Code", SalesLine) then begin
                SalesLine.Validate("Qty. to Ship", MinDecimal(ShippedQty, SalesLine."Outstanding Quantity"));
                SalesLine.Modify(true);
                AnyToShip := true;
            end;
        end;

        if not AnyToShip then
            Error(MessageMgt.CreatePermanentError(StrSubstNo(NothingToShipErr, ShipmentId, SalesHeader."No.")));
    end;

    local procedure FindOrderLine(SalesHeader: Record "Sales Header"; ItemNo: Code[20]; VariantCode: Code[10]; var SalesLine: Record "Sales Line"): Boolean
    begin
        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetRange("No.", ItemNo);
        SalesLine.SetRange("Variant Code", VariantCode);
        exit(SalesLine.FindFirst());
    end;

    local procedure LinkCorrelationParent(var IntegrationMessage: Record "Integration Message"; Reference: Code[35])
    var
        ParentMessageId: Guid;
    begin
        if Reference = '' then
            exit;
        ParentMessageId := MessageMgt.FindOutboundParent('FulfilmentRequest', Reference);
        if not IsNullGuid(ParentMessageId) then
            IntegrationMessage."Parent Message ID" := ParentMessageId;
    end;

    local procedure PostShipment(var SalesHeader: Record "Sales Header"; var IntegrationMessage: Record "Integration Message"; ShipmentId: Text; TrackingNo: Text)
    var
        IntegrationSetup: Record "Integration Setup";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesPost: Codeunit "Sales-Post";
        PostInvoice: Boolean;
        PostedShipmentNo: Code[20];
    begin
        if IntegrationSetup.Get() then
            PostInvoice := IntegrationSetup."Post Invoice On Shipment";

        SalesHeader.Ship := true;
        SalesHeader.Invoice := PostInvoice;
        SalesHeader.Receive := false;
        // Suppress the internal commit so the post stays inside the dispatcher's
        // per-message transaction: a later failure rolls the whole message back.
        SalesPost.SetSuppressCommit(true);
        SalesPost.Run(SalesHeader);

        SalesShipmentHeader.SetCurrentKey("Order No.");
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        if SalesShipmentHeader.FindLast() then
            PostedShipmentNo := SalesShipmentHeader."No.";

        RecordResult(IntegrationMessage, PostedShipmentNo, ShipmentId, TrackingNo);
    end;

    local procedure RecordResult(var IntegrationMessage: Record "Integration Message"; PostedShipmentNo: Code[20]; ShipmentId: Text; TrackingNo: Text)
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        IntegrationMessage."Document No." := PostedShipmentNo;
        ResponseJson.Add('postedShipmentNo', PostedShipmentNo);
        ResponseJson.Add('shipmentId', ShipmentId);
        ResponseJson.Add('trackingNumber', TrackingNo);
        ResponseJson.WriteTo(ResponseText);
        IntegrationMessage.SetResponse(ResponseText);
        IntegrationMessage.Modify(true);
    end;

    local procedure MinDecimal(A: Decimal; B: Decimal): Decimal
    begin
        if A < B then
            exit(A);
        exit(B);
    end;
}
