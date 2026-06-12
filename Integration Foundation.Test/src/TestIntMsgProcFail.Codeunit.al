codeunit 73298491 "Test Int. Msg. Proc. Fail" implements "IIntegration Msg. Processor"
{
    Caption = 'Test Integration Message Processor (Failing)';

    procedure Process(var IntegrationMessage: Record "Integration Message")
    begin
        Error('TEST_ERROR: Simulated processing failure for testing.');
    end;
}
