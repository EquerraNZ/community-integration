enumextension 73298451 "Shipment Confirm. Type" extends "Integration Message Type"
{
    value(73298451; "WMS Shipment Confirmation")
    {
        Caption = 'WMS Shipment Confirmation';
        Implementation = "IIntegration Msg. Processor" = "Shipment Confirm. Proc.";
    }
}
