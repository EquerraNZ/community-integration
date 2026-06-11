enumextension 73298416 "WMS Message Types" extends "Integration Message Type"
{
    // Ordinal 20 is the stable external contract value for a WMS shipment
    // confirmation. It must not be reordered. The value name (WmsShipmentConfirmation)
    // is the Type Code the integration layer sends on the inbound envelope.
    value(20; WmsShipmentConfirmation)
    {
        Caption = 'WMS Shipment Confirmation';
        Implementation = "IIntegrationMessageHandler" = "WMS Shipment Handler";
    }
}
