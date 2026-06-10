// The safety net handler bound to the Unspecified type (and the enum's default
// implementation). If a message reaches the dispatcher with a type that no
// consuming app has bound a handler to, it lands here and fails loudly with a
// clear, actionable error rather than silently doing nothing. Because the
// dispatcher runs handlers inside an isolation boundary, this error is captured
// durably on the message like any other handler failure.
codeunit 73298421 "Default Integration Handler" implements IIntegrationHandler
{
    Access = Public;

    var
        NoHandlerErr: Label 'No integration handler is registered for type %1. Bind a handler to this type with an enumextension on "Integration Type" (Implementation = IIntegrationHandler = <your handler>).', Comment = '%1 = the integration type name';

    procedure Process(var IntegrationMessage: Record "Integration Message")
    begin
        Error(NoHandlerErr, Format(IntegrationMessage.Type));
    end;
}
