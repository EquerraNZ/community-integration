interface "IIntegration Msg. Processor"
{
    /// <summary>
    /// Processes an integration message according to its type.
    /// Implementations set Response Content on success or raise an error on failure.
    /// </summary>
    procedure Process(var IntegrationMessage: Record "Integration Message");
}
