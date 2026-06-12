codeunit 73298452 "Integration Events"
{
    Caption = 'Integration Events';

    [BusinessEvent(false)]
    procedure OnAfterFulfilmentRequested(CorrelationId: Text; Payload: Text)
    begin
    end;

    [BusinessEvent(false)]
    procedure OnAfterShipmentNotify(WebstoreOrderNo: Text; Payload: Text)
    begin
    end;
}
