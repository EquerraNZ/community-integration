codeunit 73298401 "Integration Msg. Retry"
{
    Caption = 'Integration Message Retry';
    TableNo = "Job Queue Entry";

    var
        MaxRetryCountDefault: Integer;
        TelemetryTagRetryTok: Label 'INTMSG-005', Locked = true;
        TelemetryMsgRetryTxt: Label 'Integration message retry triggered.', Locked = true;

    trigger OnRun()
    begin
        MaxRetryCountDefault := 3; // Default max retry attempts per message
        RetryFailedMessages();
    end;

    local procedure RetryFailedMessages()
    var
        IntegrationMessage: Record "Integration Message";
        MessageIds: List of [Guid];
        MessageId: Guid;
    begin
        // Collect IDs first to avoid FindSet + Commit interaction.
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::Failed);
        if not IntegrationMessage.FindSet() then
            exit;

        repeat
            if IntegrationMessage."Retry Count" < MaxRetryCountDefault then
                MessageIds.Add(IntegrationMessage."Message ID");
        until IntegrationMessage.Next() = 0;

        foreach MessageId in MessageIds do begin
            IntegrationMessage.Get(MessageId);
            ResetForRetry(IntegrationMessage);
        end;
    end;

    local procedure ResetForRetry(var IntegrationMessage: Record "Integration Message")
    var
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
    begin
        IntegrationMessage."Retry Count" += 1;
        IntegrationMessage.Status := IntegrationMessage.Status::New;
        Clear(IntegrationMessage."Error Code");
        IntegrationMessage.SetErrorContent('');
        IntegrationMessage.Modify(true);
        // Commit so retry status persists before processing attempt.
        Commit();

        EmitRetryTriggered(IntegrationMessage);

        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);
    end;

    procedure RetryManual(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.TestField(Status, IntegrationMessage.Status::Failed);
        ResetForRetry(IntegrationMessage);
    end;

    local procedure EmitRetryTriggered(IntegrationMessage: Record "Integration Message")
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('MessageId', Format(IntegrationMessage."Message ID", 0, 4));
        CustomDimensions.Add('Type', Format(IntegrationMessage."Type"));
        CustomDimensions.Add('CorrelationId', Format(IntegrationMessage."Correlation ID", 0, 4));
        CustomDimensions.Add('RetryCount', Format(IntegrationMessage."Retry Count"));
        Session.LogMessage(TelemetryTagRetryTok, TelemetryMsgRetryTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
