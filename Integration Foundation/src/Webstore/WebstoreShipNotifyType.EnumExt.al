enumextension 73298421 "Webstore Ship. Notify Type" extends "Integration Message Type"
{
    value(73298421; "Webstore Shipment Notify")
    {
        Caption = 'Webstore Shipment Notify';
        Implementation = "IIntegration Msg. Processor" = "Webstore Ship. Notify Proc.";
    }
}
