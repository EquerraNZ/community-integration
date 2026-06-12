codeunit 73298422 "Webstore Shipment Notify"
{
    Caption = 'Webstore Shipment Notify';

    var
        TelemetryTagNotifiedTok: Label 'INTMSG-WEB01', Locked = true;
        TelemetryMsgNotifiedTxt: Label 'Webstore shipment notification staged.', Locked = true;
        ShipIdempotencySuffixTok: Label '-SHIP', Locked = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnAfterPostSalesDoc, '', false, false)]
    local procedure OnAfterPostSalesDoc(var SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; SalesShptHdrNo: Code[20]; RetRcpHdrNo: Code[20]; SalesInvHdrNo: Code[20]; SalesCrMemoHdrNo: Code[20]; CommitIsSuppressed: Boolean)
    begin
        // Only act on shipments (not invoices alone)
        if SalesShptHdrNo = '' then
            exit;
        // Only act on Webstore orders (identified by External Document No.)
        if SalesHeader."External Document No." = '' then
            exit;

        CreateShipmentNotification(SalesHeader, SalesShptHdrNo);
    end;

    local procedure CreateShipmentNotification(var SalesHeader: Record "Sales Header"; SalesShptHdrNo: Code[20])
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgStage: Codeunit "Integration Msg. Stage";
        Payload: Text;
        IsNew: Boolean;
    begin
        Payload := BuildPayload(SalesHeader);

        IntegrationMessage.Init();
        IntegrationMessage."Type" := "Integration Message Type"::"Webstore Shipment Notify";
        IntegrationMessage."Idempotency Key" := CopyStr(SalesHeader."External Document No." + ShipIdempotencySuffixTok, 1, 50);
        IntegrationMessage."Correlation ID" := CreateGuid();
        IntegrationMessage.Status := "Integration Message Status"::Completed;
        IntegrationMessage."Document No." := SalesShptHdrNo;

        IsNew := IntegrationMsgStage.StageMessage(IntegrationMessage, Payload);
        if IsNew then begin
            RaiseBusinessEvent(SalesHeader."External Document No.", Payload);
            EmitTelemetry(SalesHeader);
        end;
    end;

    local procedure BuildPayload(var SalesHeader: Record "Sales Header"): Text
    var
        PayloadObj: JsonObject;
        PayloadText: Text;
    begin
        PayloadObj.Add('status', 'Despatched');
        PayloadObj.Add('bcOrderNo', SalesHeader."No.");
        PayloadObj.Add('despatchedAt', Format(CurrentDateTime(), 0, 9));
        PayloadObj.WriteTo(PayloadText);
        exit(PayloadText);
    end;

    local procedure RaiseBusinessEvent(WebstoreOrderNo: Text; Payload: Text)
    var
        IntegrationEvents: Codeunit "Integration Events";
    begin
        IntegrationEvents.OnAfterShipmentNotify(WebstoreOrderNo, Payload);
    end;

    local procedure EmitTelemetry(var SalesHeader: Record "Sales Header")
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('SalesOrderNo', SalesHeader."No.");
        CustomDimensions.Add('WebstoreOrderNo', SalesHeader."External Document No.");
        Session.LogMessage(TelemetryTagNotifiedTok, TelemetryMsgNotifiedTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
