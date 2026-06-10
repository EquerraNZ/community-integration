// The handler contract. Every integration type binds to one implementation of
// this interface. The dispatcher resolves the implementation from the message's
// Type enum (the enum "implements" this interface), so adding a new integration is
// adding a handler and an enum value in a consuming app: the framework never
// changes and there is no central CASE statement to edit.
interface IIntegrationHandler
{
    /// <summary>
    /// Process one staged Integration Message. Read the request payload, do the
    /// work, and write any response. Do not set the terminal status yourself: the
    /// dispatcher marks the message Resolved when this returns without error, and
    /// Failed (capturing the error durably) when this raises one. To park a
    /// long-running request, call Integration Reply Mgt. to set Awaiting Reply.
    /// This runs inside a Codeunit.Run isolation boundary, so any error rolls back
    /// only the handler's own work, never the durable failure record.
    /// </summary>
    /// <param name="IntegrationMessage">The message to process, passed by reference.</param>
    procedure Process(var IntegrationMessage: Record "Integration Message")
}
