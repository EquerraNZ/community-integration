codeunit 73298470 "Test Integration Handler" implements "IIntegrationMessageHandler"
{
    // Stub handler for the test routing values: succeeds, fails Permanent, or fails
    // Transient depending on the message type, so the dispatcher's success and failure
    // classification paths can be asserted deterministically.

    procedure HandleMessage(var IntegrationMessage: Record "Integration Message")
    var
        MessageMgt: Codeunit "Integration Message Mgt.";
    begin
        case IntegrationMessage.Type of
            IntegrationMessage.Type::TestFailPermanent:
                Error(MessageMgt.CreatePermanentError('Test permanent failure'));
            IntegrationMessage.Type::TestFailTransient:
                Error('Test transient failure'); // plain error => classified Transient
            else begin
                IntegrationMessage."Document No." := 'TEST-OK';
                IntegrationMessage.Modify(true);
            end;
        end;
    end;
}
