codeunit 73298450 "Fulfilment Req. Processor" implements "IIntegration Msg. Processor"
{
    Caption = 'Fulfilment Request Processor';

    procedure Process(var IntegrationMessage: Record "Integration Message")
    begin
        // No-op: Fulfilment Request is an outbound-only message type.
        // Processing is not applicable; the message is staged as Completed
        // by the Fulfilment Request Mgt. codeunit at creation time.
    end;
}
