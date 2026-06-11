/// <summary>
/// Implemented by every value of enum "Integration Message Type". The dispatcher
/// resolves the handler from the message Type and calls HandleMessage, so adding a
/// new integration is one enum value plus one handler, with no dispatcher change.
/// </summary>
interface "IIntegrationMessageHandler"
{
    /// <summary>
    /// Do the Business Central work for one staged inbound message. On a data
    /// problem, raise a permanent error (see Integration Message Mgt.
    /// CreatePermanentError); transient failures should be raised as plain errors
    /// so the dispatcher retries them. Set Document No. / Response on the record
    /// before returning so the resolved message carries its BC anchor.
    /// </summary>
    procedure HandleMessage(var IntegrationMessage: Record "Integration Message")
}
