codeunit 73298451 "Fulfilment Request Mgt."
{
    Caption = 'Fulfilment Request Management';

    var
        TelemetryTagRequestedTok: Label 'INTMSG-WMS01', Locked = true;
        TelemetryMsgRequestedTxt: Label 'Fulfilment request staged successfully.', Locked = true;
        TelemetryTagFailedTok: Label 'INTMSG-WMS02', Locked = true;
        TelemetryMsgFailedTxt: Label 'Fulfilment request failed.', Locked = true;
        ErrSetupMissingLocationLbl: Label 'WMS Setup is missing the Location Code. Configure it before releasing orders.';
        ErrSKUNotMappedLbl: Label 'Item No. "%1" has no SKU mapping for Source "%2". Add a mapping in Integration SKU Mapping.', Comment = '%1 = Item No., %2 = Source';
        FulfilmentIdempotencySuffixTok: Label '-FUL', Locked = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", OnAfterReleaseSalesDoc, '', false, false)]
    local procedure OnAfterReleaseSalesDoc(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; var LinesWereModified: Boolean)
    begin
        if PreviewMode then
            exit;
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit;

        CreateFulfilmentRequest(SalesHeader);
    end;

    local procedure CreateFulfilmentRequest(var SalesHeader: Record "Sales Header")
    var
        WMSSetup: Record "WMS Setup";
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgStage: Codeunit "Integration Msg. Stage";
        Payload: Text;
        IsNew: Boolean;
    begin
        if not WMSSetup.Get() then begin
            StageFailed(SalesHeader, ErrSetupMissingLocationLbl);
            exit;
        end;
        if WMSSetup."Location Code" = '' then begin
            StageFailed(SalesHeader, ErrSetupMissingLocationLbl);
            exit;
        end;

        if not TryBuildPayload(SalesHeader, WMSSetup, Payload) then begin
            StageFailed(SalesHeader, GetLastErrorText());
            exit;
        end;

        IntegrationMessage.Init();
        IntegrationMessage."Type" := "Integration Message Type"::"Fulfilment Request";
        IntegrationMessage."Idempotency Key" := CopyStr(SalesHeader."No." + FulfilmentIdempotencySuffixTok, 1, 50);
        IntegrationMessage."Correlation ID" := GetCorrelationId(SalesHeader);
        IntegrationMessage.Status := "Integration Message Status"::Completed;
        IntegrationMessage."Document No." := SalesHeader."No.";

        IsNew := IntegrationMsgStage.StageMessage(IntegrationMessage, Payload);
        if IsNew then begin
            RaiseBusinessEvent(SalesHeader, Payload);
            EmitTelemetrySuccess(SalesHeader);
        end;
    end;

    [TryFunction]
    local procedure TryBuildPayload(var SalesHeader: Record "Sales Header"; WMSSetup: Record "WMS Setup"; var Payload: Text)
    begin
        Payload := BuildPayload(SalesHeader, WMSSetup);
    end;

    local procedure BuildPayload(var SalesHeader: Record "Sales Header"; WMSSetup: Record "WMS Setup"): Text
    var
        SalesLine: Record "Sales Line";
        SKUMapping: Record "Integration SKU Mapping";
        PayloadObj: JsonObject;
        ShipToObj: JsonObject;
        LinesArray: JsonArray;
        LineObj: JsonObject;
        ExternalSKU: Code[50];
    begin
        PayloadObj.Add('reference', SalesHeader."External Document No.");
        PayloadObj.Add('bcOrderNo', SalesHeader."No.");

        ShipToObj.Add('name', SalesHeader."Ship-to Name");
        ShipToObj.Add('line1', SalesHeader."Ship-to Address");
        ShipToObj.Add('city', SalesHeader."Ship-to City");
        ShipToObj.Add('postcode', SalesHeader."Ship-to Post Code");
        ShipToObj.Add('country', SalesHeader."Ship-to Country/Region Code");
        ShipToObj.Add('phone', SalesHeader."Ship-to Contact");
        PayloadObj.Add('shipTo', ShipToObj);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter(Quantity, '>0');
        if SalesLine.FindSet() then
            repeat
                ExternalSKU := ResolveExternalSKU(SalesLine."No.", WMSSetup."SKU Source");
                Clear(LineObj);
                LineObj.Add('sku', ExternalSKU);
                LineObj.Add('quantity', SalesLine.Quantity);
                LinesArray.Add(LineObj);
            until SalesLine.Next() = 0;

        PayloadObj.Add('lines', LinesArray);
        PayloadObj.Add('shippingMethod', WMSSetup."Shipping Method");
        PayloadObj.Add('requestedAt', Format(CurrentDateTime(), 0, 9));

        PayloadObj.WriteTo(Payload);
        exit(Payload);
    end;

    local procedure ResolveExternalSKU(ItemNo: Code[20]; SKUSource: Code[20]): Code[50]
    var
        SKUMapping: Record "Integration SKU Mapping";
    begin
        SKUMapping.SetRange(Source, SKUSource);
        SKUMapping.SetRange("Item No.", ItemNo);
        if not SKUMapping.FindFirst() then
            Error(ErrSKUNotMappedLbl, ItemNo, SKUSource);
        exit(SKUMapping."External SKU");
    end;

    local procedure StageFailed(var SalesHeader: Record "Sales Header"; ErrorMessage: Text)
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgStage: Codeunit "Integration Msg. Stage";
    begin
        IntegrationMessage.Init();
        IntegrationMessage."Type" := "Integration Message Type"::"Fulfilment Request";
        IntegrationMessage."Idempotency Key" := CopyStr(SalesHeader."No." + FulfilmentIdempotencySuffixTok, 1, 50);
        IntegrationMessage."Correlation ID" := GetCorrelationId(SalesHeader);
        IntegrationMessage.Status := "Integration Message Status"::Failed;
        IntegrationMessage."Document No." := SalesHeader."No.";
        IntegrationMessage.SetErrorContent(ErrorMessage);

        IntegrationMsgStage.StageMessage(IntegrationMessage, '');
        EmitTelemetryFailed(SalesHeader, ErrorMessage);
    end;

    local procedure RaiseBusinessEvent(var SalesHeader: Record "Sales Header"; Payload: Text)
    var
        IntegrationEvents: Codeunit "Integration Events";
    begin
        IntegrationEvents.OnAfterFulfilmentRequested(SalesHeader."External Document No.", Payload);
    end;

    local procedure GetCorrelationId(var SalesHeader: Record "Sales Header"): Guid
    var
        CorrelationText: Text;
    begin
        CorrelationText := SalesHeader."External Document No.";
        if CorrelationText = '' then
            CorrelationText := SalesHeader."No.";
        exit(CreateGuid());
    end;

    local procedure EmitTelemetrySuccess(var SalesHeader: Record "Sales Header")
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('SalesOrderNo', SalesHeader."No.");
        CustomDimensions.Add('CorrelationId', SalesHeader."External Document No.");
        Session.LogMessage(TelemetryTagRequestedTok, TelemetryMsgRequestedTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    local procedure EmitTelemetryFailed(var SalesHeader: Record "Sales Header"; ErrorReason: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('SalesOrderNo', SalesHeader."No.");
        CustomDimensions.Add('CorrelationId', SalesHeader."External Document No.");
        CustomDimensions.Add('ErrorReason', ErrorReason);
        Session.LogMessage(TelemetryTagFailedTok, TelemetryMsgFailedTxt,
            Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
