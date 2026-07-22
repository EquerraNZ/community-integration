codeunit 73298427 "Webstore Order Handler" implements "IIntegrationMessageHandler"
{
    // Inbound business process 1: turn a staged Webstore order into a standard Sales
    // Order. Runs inside the dispatcher's per-message transaction, so any failure
    // (unmapped SKU, missing setup, bad payload) rolls back the whole order and the
    // message lands Failed for resolution. Makes no external call.

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        JsonHelper: Codeunit "Integration JSON Helper";
        SKUMgt: Codeunit "Integration SKU Mgt.";
        NoCustomerErr: Label 'No Webstore customer is configured in Integration Setup. Set it before ingesting orders.';
        BadPayloadErr: Label 'The Webstore order payload could not be parsed as JSON.';
        NoOrderNoErr: Label 'The Webstore order payload has no orderNo.';
        UnmappedSKUErr: Label 'SKU ''%1'' on order ''%2'' is not mapped to a Business Central item.', Comment = '%1 = SKU, %2 = order number';

    procedure HandleMessage(var IntegrationMessage: Record "Integration Message")
    var
        IntegrationSetup: Record "Integration Setup";
        SalesHeader: Record "Sales Header";
        OrderJson: JsonObject;
        OrderNo: Code[35];
    begin
        if (not IntegrationSetup.Get()) or (IntegrationSetup."Webstore Customer No." = '') then
            Error(MessageMgt.CreatePermanentError(NoCustomerErr));

        if not JsonHelper.TryParse(IntegrationMessage.GetRequest(), OrderJson) then
            Error(MessageMgt.CreatePermanentError(BadPayloadErr));

        OrderNo := CopyStr(JsonHelper.GetText(OrderJson, 'orderNo'), 1, MaxStrLen(OrderNo));
        if OrderNo = '' then
            Error(MessageMgt.CreatePermanentError(NoOrderNoErr));

        // Idempotency backstop: if a Sales Order for this orderNo already exists, link
        // to it and resolve rather than creating a second one.
        if TryFindExistingOrder(IntegrationSetup."Webstore Customer No.", OrderNo, SalesHeader) then begin
            RecordResult(IntegrationMessage, SalesHeader."No.");
            exit;
        end;

        CreateOrder(IntegrationSetup, OrderJson, OrderNo, SalesHeader);
        RecordResult(IntegrationMessage, SalesHeader."No.");
    end;

    local procedure CreateOrder(IntegrationSetup: Record "Integration Setup"; OrderJson: JsonObject; OrderNo: Code[35]; var SalesHeader: Record "Sales Header")
    var
        CustomerJson: JsonObject;
        AddressJson: JsonObject;
    begin
        SalesHeader.Init();
        SalesHeader.Validate("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader."No." := '';
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", IntegrationSetup."Webstore Customer No.");
        SalesHeader.Validate("External Document No.", OrderNo);
        if IntegrationSetup."Default Location Code" <> '' then
            SalesHeader.Validate("Location Code", IntegrationSetup."Default Location Code");
        if IntegrationSetup."Default Shipment Method Code" <> '' then
            SalesHeader.Validate("Shipment Method Code", IntegrationSetup."Default Shipment Method Code");

        if JsonHelper.GetObject(OrderJson, 'customer', CustomerJson) then begin
            SalesHeader."Ship-to Name" := CopyStr(JsonHelper.GetText(CustomerJson, 'name'), 1, MaxStrLen(SalesHeader."Ship-to Name"));
            SalesHeader."Sell-to E-Mail" := CopyStr(JsonHelper.GetText(CustomerJson, 'email'), 1, MaxStrLen(SalesHeader."Sell-to E-Mail"));
            SalesHeader."Ship-to Phone No." := CopyStr(JsonHelper.GetText(CustomerJson, 'phone'), 1, MaxStrLen(SalesHeader."Ship-to Phone No."));
            if JsonHelper.GetObject(CustomerJson, 'address', AddressJson) then begin
                SalesHeader."Ship-to Address" := CopyStr(JsonHelper.GetText(AddressJson, 'line1'), 1, MaxStrLen(SalesHeader."Ship-to Address"));
                SalesHeader."Ship-to Address 2" := CopyStr(JsonHelper.GetText(AddressJson, 'line2'), 1, MaxStrLen(SalesHeader."Ship-to Address 2"));
                SalesHeader."Ship-to City" := CopyStr(JsonHelper.GetText(AddressJson, 'city'), 1, MaxStrLen(SalesHeader."Ship-to City"));
                SalesHeader."Ship-to Post Code" := CopyStr(JsonHelper.GetText(AddressJson, 'postcode'), 1, MaxStrLen(SalesHeader."Ship-to Post Code"));
                SalesHeader."Ship-to Country/Region Code" := CopyStr(JsonHelper.GetText(AddressJson, 'country'), 1, MaxStrLen(SalesHeader."Ship-to Country/Region Code"));
            end;
        end;
        SalesHeader.Modify(true);

        CreateLines(SalesHeader, OrderJson, OrderNo);
    end;

    local procedure CreateLines(SalesHeader: Record "Sales Header"; OrderJson: JsonObject; OrderNo: Code[35])
    var
        SalesLine: Record "Sales Line";
        SKUMapping: Record "Integration SKU Mapping";
        LinesArray: JsonArray;
        LineToken: JsonToken;
        LineJson: JsonObject;
        SKU: Code[20];
        LineNo: Integer;
    begin
        if not JsonHelper.GetArray(OrderJson, 'lines', LinesArray) then
            exit;

        foreach LineToken in LinesArray do begin
            LineJson := LineToken.AsObject();
            SKU := CopyStr(JsonHelper.GetText(LineJson, 'sku'), 1, MaxStrLen(SKU));
            if not SKUMgt.TryGetMapping(SKU, SKUMapping) then
                Error(MessageMgt.CreatePermanentError(StrSubstNo(UnmappedSKUErr, SKU, OrderNo)));

            LineNo += 10000;
            SalesLine.Init();
            SalesLine."Document Type" := SalesHeader."Document Type";
            SalesLine."Document No." := SalesHeader."No.";
            SalesLine."Line No." := LineNo;
            SalesLine.Validate(Type, SalesLine.Type::Item);
            SalesLine.Validate("No.", SKUMapping."Item No.");
            if SKUMapping."Variant Code" <> '' then
                SalesLine.Validate("Variant Code", SKUMapping."Variant Code");
            if SKUMapping."Unit of Measure Code" <> '' then
                SalesLine.Validate("Unit of Measure Code", SKUMapping."Unit of Measure Code");
            SalesLine.Validate(Quantity, JsonHelper.GetDecimal(LineJson, 'quantity'));
            SalesLine.Validate("Unit Price", JsonHelper.GetDecimal(LineJson, 'unitPrice'));
            SalesLine.Insert(true);
        end;
    end;

    local procedure TryFindExistingOrder(CustomerNo: Code[20]; OrderNo: Code[35]; var SalesHeader: Record "Sales Header"): Boolean
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("Sell-to Customer No.", CustomerNo);
        SalesHeader.SetRange("External Document No.", OrderNo);
        exit(SalesHeader.FindFirst());
    end;

    local procedure RecordResult(var IntegrationMessage: Record "Integration Message"; OrderNo: Code[20])
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        IntegrationMessage."Document No." := OrderNo;
        ResponseJson.Add('bcOrderNo', OrderNo);
        ResponseJson.Add('status', 'Created');
        ResponseJson.WriteTo(ResponseText);
        IntegrationMessage.SetResponse(ResponseText);
        IntegrationMessage.Modify(true);
    end;
}
