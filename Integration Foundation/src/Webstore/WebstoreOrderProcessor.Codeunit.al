codeunit 73298420 "Webstore Order Processor" implements "IIntegration Msg. Processor"
{
    Caption = 'Webstore Order Processor';

    var
        WebstoreSourceTok: Label 'WEBSTORE', Locked = true;
        TelemetryTagOrderProcessedTok: Label 'INTMSG-W01', Locked = true;
        TelemetryMsgOrderProcessedTxt: Label 'Webstore order processed successfully.', Locked = true;
        TelemetryTagSKUFailedTok: Label 'INTMSG-W02', Locked = true;
        TelemetryMsgSKUFailedTxt: Label 'SKU resolution failed for Webstore order.', Locked = true;
        ErrSetupMissingCustomerLbl: Label 'Webstore Setup is missing the Customer No. Configure it before processing orders.';
        ErrSKUNotMappedLbl: Label 'SKU "%1" is not mapped to a BC Item. Add a mapping in Integration SKU Mapping for Source = WEBSTORE.', Comment = '%1 = the unmapped SKU value';

    procedure Process(var IntegrationMessage: Record "Integration Message")
    var
        WebstoreSetup: Record "Webstore Setup";
        SalesHeader: Record "Sales Header";
        RequestContent: Text;
        OrderJson: JsonObject;
    begin
        // Validate setup
        WebstoreSetup.Get();
        if WebstoreSetup."Customer No." = '' then
            Error(ErrSetupMissingCustomerLbl);

        // Parse request content
        RequestContent := IntegrationMessage.GetRequestContent();
        OrderJson.ReadFrom(RequestContent);

        // Create the Sales Order
        CreateSalesOrder(OrderJson, WebstoreSetup, SalesHeader);

        // Record the BC order number on the integration message
        IntegrationMessage."Document No." := SalesHeader."No.";
        IntegrationMessage.Modify(true);

        EmitOrderProcessed(IntegrationMessage, SalesHeader."No.");
    end;

    local procedure CreateSalesOrder(OrderJson: JsonObject; WebstoreSetup: Record "Webstore Setup"; var SalesHeader: Record "Sales Header")
    var
        LinesToken: JsonToken;
        LinesArray: JsonArray;
        LineToken: JsonToken;
        LineObject: JsonObject;
        i: Integer;
    begin
        // Create Sales Header
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader.Insert(true);

        SalesHeader.Validate("Sell-to Customer No.", WebstoreSetup."Customer No.");
        SalesHeader.Validate("External Document No.", GetJsonText(OrderJson, 'orderNo'));
        SalesHeader.Validate("Posting Date", GetPostingDate(OrderJson));
        SetShipToAddress(SalesHeader, OrderJson);

        if WebstoreSetup."Location Code" <> '' then
            SalesHeader.Validate("Location Code", WebstoreSetup."Location Code");

        SalesHeader.Modify(true);

        // Create Sales Lines
        OrderJson.Get('lines', LinesToken);
        LinesArray := LinesToken.AsArray();

        for i := 0 to LinesArray.Count() - 1 do begin
            LinesArray.Get(i, LineToken);
            LineObject := LineToken.AsObject();
            CreateSalesLine(SalesHeader, LineObject, WebstoreSetup, i + 1);
        end;
    end;

    local procedure CreateSalesLine(SalesHeader: Record "Sales Header"; LineJson: JsonObject; WebstoreSetup: Record "Webstore Setup"; LineNo: Integer)
    var
        SalesLine: Record "Sales Line";
        ItemNo: Code[20];
        SKU: Text;
    begin
        SKU := GetJsonText(LineJson, 'sku');
        ItemNo := ResolveSKU(SKU);

        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := LineNo * 10000;
        SalesLine.Insert(true);

        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", ItemNo);
        SalesLine.Validate(Quantity, GetJsonDecimal(LineJson, 'quantity'));
        SalesLine.Validate("Unit Price", GetJsonDecimal(LineJson, 'unitPrice'));

        if WebstoreSetup."Location Code" <> '' then
            SalesLine.Validate("Location Code", WebstoreSetup."Location Code");

        SalesLine.Modify(true);
    end;

    local procedure ResolveSKU(SKU: Text): Code[20]
    var
        IntegrationSKUMapping: Record "Integration SKU Mapping";
    begin
        if not IntegrationSKUMapping.Get(WebstoreSourceTok, UpperCase(SKU)) then begin
            EmitSKUFailed(SKU);
            Error(ErrSKUNotMappedLbl, SKU);
        end;
        exit(IntegrationSKUMapping."Item No.");
    end;

    local procedure SetShipToAddress(var SalesHeader: Record "Sales Header"; OrderJson: JsonObject)
    var
        CustomerToken: JsonToken;
        CustomerObj: JsonObject;
        AddressToken: JsonToken;
        AddressObj: JsonObject;
    begin
        if not OrderJson.Get('customer', CustomerToken) then
            exit;
        CustomerObj := CustomerToken.AsObject();

        SalesHeader."Ship-to Name" := CopyStr(GetJsonText(CustomerObj, 'name'), 1, MaxStrLen(SalesHeader."Ship-to Name"));
        SalesHeader."Ship-to Contact" := CopyStr(GetJsonText(CustomerObj, 'phone'), 1, MaxStrLen(SalesHeader."Ship-to Contact"));

        if not CustomerObj.Get('address', AddressToken) then
            exit;
        AddressObj := AddressToken.AsObject();

        SalesHeader."Ship-to Address" := CopyStr(GetJsonText(AddressObj, 'line1'), 1, MaxStrLen(SalesHeader."Ship-to Address"));
        SalesHeader."Ship-to Address 2" := CopyStr(GetJsonText(AddressObj, 'line2'), 1, MaxStrLen(SalesHeader."Ship-to Address 2"));
        SalesHeader."Ship-to City" := CopyStr(GetJsonText(AddressObj, 'city'), 1, MaxStrLen(SalesHeader."Ship-to City"));
        SalesHeader."Ship-to Post Code" := CopyStr(GetJsonText(AddressObj, 'postcode'), 1, MaxStrLen(SalesHeader."Ship-to Post Code"));
        SalesHeader."Ship-to Country/Region Code" := CopyStr(GetJsonText(AddressObj, 'country'), 1, MaxStrLen(SalesHeader."Ship-to Country/Region Code"));
    end;

    local procedure GetPostingDate(OrderJson: JsonObject): Date
    var
        PlacedAtText: Text;
        PlacedAtDateTime: DateTime;
    begin
        PlacedAtText := GetJsonText(OrderJson, 'placedAt');
        if PlacedAtText = '' then
            exit(WorkDate());
        Evaluate(PlacedAtDateTime, PlacedAtText);
        exit(DT2Date(PlacedAtDateTime));
    end;

    local procedure GetJsonText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
        Value: JsonValue;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        Value := Token.AsValue();
        if Value.IsNull() or Value.IsUndefined() then
            exit('');
        exit(Value.AsText());
    end;

    local procedure GetJsonDecimal(JsonObj: JsonObject; PropertyName: Text): Decimal
    var
        Token: JsonToken;
        Value: JsonValue;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit(0);
        if not Token.IsValue() then
            exit(0);
        Value := Token.AsValue();
        if Value.IsNull() or Value.IsUndefined() then
            exit(0);
        exit(Value.AsDecimal());
    end;

    local procedure EmitOrderProcessed(IntegrationMessage: Record "Integration Message"; SalesOrderNo: Code[20])
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('MessageId', Format(IntegrationMessage."Message ID", 0, 4));
        CustomDimensions.Add('CorrelationId', Format(IntegrationMessage."Correlation ID", 0, 4));
        CustomDimensions.Add('OrderNo', IntegrationMessage."Idempotency Key");
        CustomDimensions.Add('BCSalesOrderNo', SalesOrderNo);
        Session.LogMessage(TelemetryTagOrderProcessedTok, TelemetryMsgOrderProcessedTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    local procedure EmitSKUFailed(SKU: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('SKU', SKU);
        Session.LogMessage(TelemetryTagSKUFailedTok, TelemetryMsgSKUFailedTxt,
            Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
