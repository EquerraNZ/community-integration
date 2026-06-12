codeunit 73298453 "Shipment Confirm. Proc." implements "IIntegration Msg. Processor"
{
    Caption = 'Shipment Confirmation Processor';

    var
        TelemetryTagProcessedTok: Label 'INTMSG-WMS03', Locked = true;
        TelemetryMsgProcessedTxt: Label 'Shipment confirmation processed successfully.', Locked = true;
        TelemetryTagFailedTok: Label 'INTMSG-WMS04', Locked = true;
        TelemetryMsgFailedTxt: Label 'Shipment confirmation processing failed.', Locked = true;
        ErrOrderNotFoundLbl: Label 'Sales Order "%1" not found or is not open/released.', Comment = '%1 = bcOrderNo';
        ErrSKUNotMappedLbl: Label 'SKU "%1" cannot be resolved to an Item No. for Source "%2".', Comment = '%1 = SKU, %2 = Source';
        ErrNoLinesMatchedLbl: Label 'No Sales Lines matched the shipped SKUs for order "%1".', Comment = '%1 = bcOrderNo';

    procedure Process(var IntegrationMessage: Record "Integration Message")
    var
        WMSSetup: Record "WMS Setup";
        SalesHeader: Record "Sales Header";
        PayloadJson: JsonObject;
        BcOrderNo: Text;
        ShipmentNo: Code[20];
    begin
        WMSSetup.Get();

        PayloadJson.ReadFrom(IntegrationMessage.GetRequestContent());
        BcOrderNo := GetJsonText(PayloadJson, 'bcOrderNo');

        FindSalesOrder(BcOrderNo, SalesHeader);
        ApplyShippedQuantities(SalesHeader, PayloadJson, WMSSetup."SKU Source");
        RecordCarrierAndTracking(SalesHeader, PayloadJson);
        ShipmentNo := PostSalesOrder(SalesHeader, WMSSetup."Post Invoice");

        IntegrationMessage."Document No." := ShipmentNo;
        IntegrationMessage.Modify();

        EmitTelemetrySuccess(SalesHeader."No.", ShipmentNo, IntegrationMessage);
    end;

    local procedure FindSalesOrder(BcOrderNo: Text; var SalesHeader: Record "Sales Header")
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("No.", CopyStr(BcOrderNo, 1, 20));
        SalesHeader.SetFilter(Status, '%1|%2',
            SalesHeader.Status::Open, SalesHeader.Status::Released);
        if not SalesHeader.FindFirst() then
            Error(ErrOrderNotFoundLbl, BcOrderNo);
    end;

    local procedure ApplyShippedQuantities(var SalesHeader: Record "Sales Header"; PayloadJson: JsonObject; SKUSource: Code[20])
    var
        SalesLine: Record "Sales Line";
        LinesToken: JsonToken;
        LinesArray: JsonArray;
        LineToken: JsonToken;
        LineObj: JsonObject;
        SKU: Text;
        ShippedQty: Decimal;
        ItemNo: Code[20];
        AnyLineMatched: Boolean;
    begin
        PayloadJson.Get('lines', LinesToken);
        LinesArray := LinesToken.AsArray();

        foreach LineToken in LinesArray do begin
            LineObj := LineToken.AsObject();
            SKU := GetJsonText(LineObj, 'sku');
            ShippedQty := GetJsonDecimal(LineObj, 'shippedQuantity');
            ItemNo := ResolveItemNo(SKU, SKUSource);

            SalesLine.SetRange("Document Type", SalesHeader."Document Type");
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetRange(Type, SalesLine.Type::Item);
            SalesLine.SetRange("No.", ItemNo);
            SalesLine.SetFilter("Outstanding Quantity", '>0');
            if SalesLine.FindFirst() then begin
                SalesLine.Validate("Qty. to Ship", ShippedQty);
                SalesLine.Modify(true);
                AnyLineMatched := true;
            end;
        end;

        if not AnyLineMatched then
            Error(ErrNoLinesMatchedLbl, SalesHeader."No.");
    end;

    local procedure ResolveItemNo(SKU: Text; SKUSource: Code[20]): Code[20]
    var
        SKUMapping: Record "Integration SKU Mapping";
    begin
        SKUMapping.SetRange(Source, SKUSource);
        SKUMapping.SetRange("External SKU", CopyStr(SKU, 1, 50));
        if not SKUMapping.FindFirst() then
            Error(ErrSKUNotMappedLbl, SKU, SKUSource);
        exit(SKUMapping."Item No.");
    end;

    local procedure RecordCarrierAndTracking(var SalesHeader: Record "Sales Header"; PayloadJson: JsonObject)
    var
        ShippingAgent: Record "Shipping Agent";
        CarrierText: Text;
        TrackingNo: Text;
        CarrierCode: Code[10];
    begin
        CarrierText := GetJsonText(PayloadJson, 'carrier');
        TrackingNo := GetJsonText(PayloadJson, 'trackingNumber');

        if CarrierText <> '' then begin
            CarrierCode := CopyStr(CarrierText, 1, 10);
            if not ShippingAgent.Get(CarrierCode) then begin
                ShippingAgent.Init();
                ShippingAgent.Code := CarrierCode;
                ShippingAgent.Name := CopyStr(CarrierText, 1, 50);
                ShippingAgent.Insert();
            end;
            SalesHeader.Validate("Shipping Agent Code", CarrierCode);
        end;

        if TrackingNo <> '' then
            SalesHeader."Package Tracking No." := CopyStr(TrackingNo, 1, 30);

        SalesHeader.Modify(true);
    end;

    local procedure PostSalesOrder(var SalesHeader: Record "Sales Header"; PostInvoice: Boolean): Code[20]
    var
        SalesPost: Codeunit "Sales-Post";
        SalesShipmentHeader: Record "Sales Shipment Header";
    begin
        SalesHeader.Ship := true;
        SalesHeader.Invoice := PostInvoice;
        SalesPost.Run(SalesHeader);

        // Find the posted shipment to return its No.
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        SalesShipmentHeader.FindLast();
        exit(SalesShipmentHeader."No.");
    end;

    local procedure GetJsonText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(PropertyName, Token) then
            if not Token.AsValue().IsNull() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure GetJsonDecimal(JsonObj: JsonObject; PropertyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(PropertyName, Token) then
            if not Token.AsValue().IsNull() then
                exit(Token.AsValue().AsDecimal());
        exit(0);
    end;

    local procedure EmitTelemetrySuccess(SalesOrderNo: Code[20]; ShipmentNo: Code[20]; IntegrationMessage: Record "Integration Message")
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('SalesOrderNo', SalesOrderNo);
        CustomDimensions.Add('ShipmentNo', ShipmentNo);
        CustomDimensions.Add('CorrelationId', Format(IntegrationMessage."Correlation ID", 0, 4));
        Session.LogMessage(TelemetryTagProcessedTok, TelemetryMsgProcessedTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
