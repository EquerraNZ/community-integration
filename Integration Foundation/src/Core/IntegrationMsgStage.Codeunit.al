codeunit 73298402 "Integration Msg. Stage"
{
    Caption = 'Integration Message Stage';

    var
        TelemetryTagStagedTok: Label 'INTMSG-001', Locked = true;
        TelemetryMsgStagedTxt: Label 'Integration message staged.', Locked = true;

    procedure StageMessage(var IntegrationMessage: Record "Integration Message"; RequestContent: Text): Boolean
    var
        ExistingMessage: Record "Integration Message";
    begin
        // Idempotency: if a record with this key already exists, return it
        if IntegrationMessage."Idempotency Key" <> '' then begin
            ExistingMessage.SetRange("Idempotency Key", IntegrationMessage."Idempotency Key");
            if ExistingMessage.FindFirst() then begin
                IntegrationMessage.TransferFields(ExistingMessage);
                exit(false); // Not a new message
            end;
        end;

        // Stage the request content
        if RequestContent <> '' then
            IntegrationMessage.SetRequestContent(RequestContent);

        IntegrationMessage.Insert(true);
        EmitMessageStaged(IntegrationMessage);
        exit(true); // New message staged
    end;

    procedure StageAndProcess(var IntegrationMessage: Record "Integration Message"; RequestContent: Text)
    var
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
        IsNew: Boolean;
    begin
        IsNew := StageMessage(IntegrationMessage, RequestContent);
        if IsNew then
            IntegrationMsgProcess.ProcessMessage(IntegrationMessage);
    end;

    local procedure EmitMessageStaged(IntegrationMessage: Record "Integration Message")
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('MessageId', Format(IntegrationMessage."Message ID", 0, 4));
        CustomDimensions.Add('Type', Format(IntegrationMessage."Type"));
        CustomDimensions.Add('IdempotencyKey', IntegrationMessage."Idempotency Key");
        CustomDimensions.Add('CorrelationId', Format(IntegrationMessage."Correlation ID", 0, 4));
        Session.LogMessage(TelemetryTagStagedTok, TelemetryMsgStagedTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
