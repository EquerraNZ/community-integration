codeunit 73298430 "Integration Outbound Events"
{
    // The outbound arrow. BC never calls an external service; it raises these external
    // business events, and the integration layer subscribes and makes the call.
    // Delivery is async and post-commit, so raising from a release or posting path is
    // safe: a rolled-back transaction never notifies. One versioned procedure per
    // contract; a contract change is a new _v2 procedure, never a mutated signature.
    Access = Public;

    /// <summary>
    /// Raised when a Webstore-originated sales order is released. Carries the stable
    /// identifiers the integration layer needs (reference = order number, bcOrderNo,
    /// correlation id). The full fulfilment request DTO is on the staged outbound
    /// Integration Message (keyed on the same reference), because external business
    /// event arguments are capped at 250 characters and a multi-line order exceeds
    /// that. The integration layer uses reference as the WMS Idempotency-Key.
    /// </summary>
    [ExternalBusinessEvent('OnSalesOrderReleased_v1', 'Sales order released for fulfilment', 'Raised when a Webstore sales order is released. Identifiers only; the full fulfilment request is on the staged outbound integration message.', EventCategory::IntegrationFoundation, '1.0')]
    procedure OnSalesOrderReleased_v1(reference: Text[100]; bcOrderNo: Text[50]; correlationId: Text[100])
    begin
    end;

    /// <summary>
    /// Raised once after a Webstore order's shipment posts. Carries the storefront
    /// order number, the BC order number, the correlation id, and the despatch
    /// timestamp. The integration layer PATCHes the storefront to Despatched.
    /// </summary>
    [ExternalBusinessEvent('OnShipmentConfirmed_v1', 'Shipment confirmed and despatched', 'Raised after a Webstore order shipment is posted, so the storefront can be set to Despatched.', EventCategory::IntegrationFoundation, '1.0')]
    procedure OnShipmentConfirmed_v1(orderNo: Text[100]; bcOrderNo: Text[50]; correlationId: Text[100]; despatchedAt: Text[50])
    begin
    end;
}
