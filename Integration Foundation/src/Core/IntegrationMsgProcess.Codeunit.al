codeunit 73298400 "Integration Msg. Process"
{
    Caption = 'Integration Message Process';
    TableNo = "Integration Message";

    var
        TelemetryTagProcessStartedTok: Label 'INTMSG-002', Locked = true;
        TelemetryTagProcessCompletedTok: Label 'INTMSG-003', Locked = true;
        TelemetryTagProcessFailedTok: Label 'INTMSG-004', Locked = true;
        TelemetryMsgProcessStartedTxt: Label 'Integration message processing started.', Locked = true;
        TelemetryMsgProcessCompletedTxt: Label 'Integration message processing completed.', Locked = true;
        TelemetryMsgProcessFailedTxt: Label 'Integration message processing failed.', Locked = true;

    trigger OnRun()
    begin
        // Atomic sub-operation: process a single message in its own transaction.
        ProcessMessage(Rec);
    end;

    procedure ProcessMessage(var IntegrationMessage: Record "Integration Message")
    var
        StartTime: DateTime;
        DurationMs: Integer;
    begin
        IntegrationMessage.Status := IntegrationMessage.Status::"In Progress";
        IntegrationMessage."Processed At" := CurrentDateTime();
        IntegrationMessage.Modify(true);
        // Commit so that In Progress status persists even if TryProcess rolls back.
        Commit();

        StartTime := CurrentDateTime();
        EmitProcessStarted(IntegrationMessage);

        if not TryProcess(IntegrationMessage) then begin
            DurationMs := CurrentDateTime() - StartTime;
            HandleProcessingError(IntegrationMessage, DurationMs);
            exit;
        end;

        DurationMs := CurrentDateTime() - StartTime;
        IntegrationMessage.Status := IntegrationMessage.Status::Completed;
        IntegrationMessage.Modify(true);
        EmitProcessCompleted(IntegrationMessage, DurationMs);
    end;

    procedure ProcessNewMessages()
    var
        IntegrationMessage: Record "Integration Message";
        MessageIds: List of [Guid];
        MessageId: Guid;
    begin
        // Collect IDs first, then process each via Codeunit.Run for per-item
        // transaction boundaries without Commit inside a loop.
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::New);
        if IntegrationMessage.FindSet() then
            repeat
                MessageIds.Add(IntegrationMessage."Message ID");
            until IntegrationMessage.Next() = 0;

        foreach MessageId in MessageIds do begin
            IntegrationMessage.Get(MessageId);
            if not Codeunit.Run(Codeunit::"Integration Msg. Process", IntegrationMessage) then
                // Per-item failure is handled inside ProcessMessage (status set to Failed).
                // If OnRun itself fails unexpectedly, the message stays In Progress
                // and will be picked up on the next cycle.
                ;
        end;
    end;

    [TryFunction]
    local procedure TryProcess(var IntegrationMessage: Record "Integration Message")
    var
        IProcessor: Interface "IIntegration Msg. Processor";
    begin
        IProcessor := IntegrationMessage."Type";
        IProcessor.Process(IntegrationMessage);
    end;

    local procedure HandleProcessingError(var IntegrationMessage: Record "Integration Message"; DurationMs: Integer)
    var
        ErrorText: Text;
    begin
        ErrorText := GetLastErrorText();
        IntegrationMessage.Status := IntegrationMessage.Status::Failed;
        IntegrationMessage.SetErrorContent(ErrorText);
        IntegrationMessage."Error Code" := CopyStr(GetLastErrorCode(), 1, MaxStrLen(IntegrationMessage."Error Code"));
        IntegrationMessage.Modify(true);
        EmitProcessFailed(IntegrationMessage, DurationMs);
    end;

    local procedure EmitProcessStarted(IntegrationMessage: Record "Integration Message")
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('MessageId', Format(IntegrationMessage."Message ID", 0, 4));
        CustomDimensions.Add('Type', Format(IntegrationMessage."Type"));
        CustomDimensions.Add('CorrelationId', Format(IntegrationMessage."Correlation ID", 0, 4));
        Session.LogMessage(TelemetryTagProcessStartedTok, TelemetryMsgProcessStartedTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    local procedure EmitProcessCompleted(IntegrationMessage: Record "Integration Message"; DurationMs: Integer)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('MessageId', Format(IntegrationMessage."Message ID", 0, 4));
        CustomDimensions.Add('Type', Format(IntegrationMessage."Type"));
        CustomDimensions.Add('CorrelationId', Format(IntegrationMessage."Correlation ID", 0, 4));
        CustomDimensions.Add('DurationMs', Format(DurationMs));
        Session.LogMessage(TelemetryTagProcessCompletedTok, TelemetryMsgProcessCompletedTxt,
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    local procedure EmitProcessFailed(IntegrationMessage: Record "Integration Message"; DurationMs: Integer)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('MessageId', Format(IntegrationMessage."Message ID", 0, 4));
        CustomDimensions.Add('Type', Format(IntegrationMessage."Type"));
        CustomDimensions.Add('CorrelationId', Format(IntegrationMessage."Correlation ID", 0, 4));
        CustomDimensions.Add('ErrorCode', IntegrationMessage."Error Code");
        CustomDimensions.Add('DurationMs', Format(DurationMs));
        Session.LogMessage(TelemetryTagProcessFailedTok, TelemetryMsgProcessFailedTxt,
            Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
