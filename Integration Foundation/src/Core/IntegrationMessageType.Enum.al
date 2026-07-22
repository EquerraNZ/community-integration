enum 73298412 "Integration Message Type" implements "IIntegrationMessageHandler"
{
    Extensible = true;
    Caption = 'Integration Message Type';
    DefaultImplementation = "IIntegrationMessageHandler" = "Integration Unknown Handler";

    /// <summary>
    /// The routing fallback. A message whose external Type Code does not resolve to
    /// a registered value lands here, and the Unknown handler fails it Permanent
    /// rather than silently skipping it. Integration modules add their own values
    /// (for example WebstoreOrder, WmsShipmentConfirmation) with their own handler.
    /// Reordering or renumbering values is forbidden: external contracts and stored
    /// rows depend on them.
    /// </summary>
    value(0; Unknown) { Caption = 'Unknown'; }
}
