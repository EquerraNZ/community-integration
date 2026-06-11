enumextension 73298414 "Webstore Message Types" extends "Integration Message Type"
{
    // Ordinal 10 is the stable external contract value for a Webstore order. It must
    // not be reordered or renumbered: stored rows and the integration contract depend
    // on it. The value name (WebstoreOrder) is the Type Code the integration layer
    // sends on the inbound envelope.
    value(10; WebstoreOrder)
    {
        Caption = 'Webstore Order';
        Implementation = "IIntegrationMessageHandler" = "Webstore Order Handler";
    }
}
