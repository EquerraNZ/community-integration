codeunit 73298423 "Integration Unknown Handler" implements "IIntegrationMessageHandler"
{
    // The routing fallback for enum value Unknown: a message whose external Type Code
    // did not resolve to a registered type. It fails the message Permanent with a clear
    // error so an unhandled type lands on the resolution page rather than being skipped.
    Access = Internal;

    procedure HandleMessage(var IntegrationMessage: Record "Integration Message")
    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        NoHandlerErr: Label 'No handler is registered for integration message type ''%1''.', Comment = '%1 = the external message type code on the message';
    begin
        Error(MessageMgt.CreatePermanentError(StrSubstNo(NoHandlerErr, IntegrationMessage."Type Code")));
    end;
}
