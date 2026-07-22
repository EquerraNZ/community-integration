codeunit 73298422 "Integration Telemetry"
{
    Access = Internal;

    /// <summary>
    /// Emit one Application Insights telemetry line for an integration message step.
    /// Custom dimensions carry the trace identifiers only: correlation id, message id,
    /// type, direction, status, error class, retry count. No payload bodies and no
    /// PII ever reach telemetry (the Description argument is a fixed, locked string).
    /// </summary>
    procedure LogMessageEvent(EventId: Text; Description: Text; Verbosity: Verbosity; var IntegrationMessage: Record "Integration Message")
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('correlationId', IntegrationMessage."Correlation ID");
        Dimensions.Add('messageId', Format(IntegrationMessage."Message ID", 0, 4));
        Dimensions.Add('messageType', IntegrationMessage."Type Code");
        Dimensions.Add('direction', Format(IntegrationMessage.Direction));
        Dimensions.Add('status', Format(IntegrationMessage.Status));
        Dimensions.Add('errorClass', Format(IntegrationMessage."Error Class"));
        Dimensions.Add('retryCount', Format(IntegrationMessage."Retry Count"));

        Session.LogMessage(
            EventId,
            Description,
            Verbosity,
            DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher,
            Dimensions);
    end;
}
