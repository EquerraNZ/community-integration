codeunit 73298490 "Test Integration Msg. Proc." implements "IIntegration Msg. Processor"
{
    Caption = 'Test Integration Message Processor';

    procedure Process(var IntegrationMessage: Record "Integration Message")
    begin
        IntegrationMessage.SetResponseContent('{"result":"ok"}');
    end;
}
