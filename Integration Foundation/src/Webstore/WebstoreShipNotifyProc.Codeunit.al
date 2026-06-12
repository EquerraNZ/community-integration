codeunit 73298421 "Webstore Ship. Notify Proc." implements "IIntegration Msg. Processor"
{
    Caption = 'Webstore Shipment Notify Processor';

    procedure Process(var IntegrationMessage: Record "Integration Message")
    begin
        // No-op: Webstore Shipment Notify is an outbound-only message type.
        // The message is staged as Completed by the subscriber at creation time.
    end;
}
