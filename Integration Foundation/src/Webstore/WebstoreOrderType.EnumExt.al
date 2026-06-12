enumextension 73298420 "Webstore Order Type" extends "Integration Message Type"
{
    value(73298420; "Webstore Order")
    {
        Caption = 'Webstore Order';
        Implementation = "IIntegration Msg. Processor" = "Webstore Order Processor";
    }
}
