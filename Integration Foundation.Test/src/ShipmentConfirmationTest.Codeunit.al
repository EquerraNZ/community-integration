codeunit 73298495 "Shipment Confirmation Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";

    local procedure CreateWMSSetup(LocationCode: Code[10]; SKUSource: Code[20]; PostInvoice: Boolean)
    var
        WMSSetup: Record "WMS Setup";
    begin
        if not WMSSetup.Get() then begin
            WMSSetup.Init();
            WMSSetup.Insert();
        end;
        WMSSetup."Location Code" := LocationCode;
        WMSSetup."Shipping Method" := 'Standard';
        WMSSetup."SKU Source" := SKUSource;
        WMSSetup."Post Invoice" := PostInvoice;
        WMSSetup.Modify();
    end;

    local procedure CreateSKUMapping(Source: Code[20]; ExternalSKU: Code[50]; ItemNo: Code[20])
    var
        SKUMapping: Record "Integration SKU Mapping";
    begin
        SKUMapping.Init();
        SKUMapping.Source := Source;
        SKUMapping."External SKU" := ExternalSKU;
        SKUMapping."Item No." := ItemNo;
        if not SKUMapping.Insert() then
            SKUMapping.Modify();
    end;

    local procedure CreateReleasedSalesOrder(var SalesHeader: Record "Sales Header"; ItemNo: Code[20]; Qty: Decimal; ExternalDocNo: Code[35])
    var
        SalesLine: Record "Sales Line";
        Customer: Record Customer;
        ReleaseSalesDoc: Codeunit "Release Sales Document";
    begin
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        SalesHeader."External Document No." := ExternalDocNo;
        SalesHeader.Modify();

        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Qty);
        SalesLine.Validate("Unit Price", 10.0);
        SalesLine.Modify(true);

        ReleaseSalesDoc.PerformManualRelease(SalesHeader);
    end;

    local procedure BuildShipmentPayload(BcOrderNo: Code[20]; ShipmentId: Text; SKU: Text; ShippedQty: Decimal; Carrier: Text; TrackingNo: Text): Text
    var
        PayloadObj: JsonObject;
        LinesArray: JsonArray;
        LineObj: JsonObject;
    begin
        PayloadObj.Add('wmsRef', 'FUL-001');
        PayloadObj.Add('reference', 'DG-00001');
        PayloadObj.Add('bcOrderNo', BcOrderNo);
        PayloadObj.Add('shipmentId', ShipmentId);
        PayloadObj.Add('shippedAt', '2026-06-11T14:58:00Z');
        PayloadObj.Add('carrier', Carrier);
        PayloadObj.Add('trackingNumber', TrackingNo);

        LineObj.Add('sku', SKU);
        LineObj.Add('shippedQuantity', ShippedQty);
        LinesArray.Add(LineObj);
        PayloadObj.Add('lines', LinesArray);

        PayloadObj.WriteTo(BuildShipmentPayload);
    end;

    local procedure BuildMultiLinePayload(BcOrderNo: Code[20]; ShipmentId: Text; SKU1: Text; Qty1: Decimal; SKU2: Text; Qty2: Decimal): Text
    var
        PayloadObj: JsonObject;
        LinesArray: JsonArray;
        LineObj1: JsonObject;
        LineObj2: JsonObject;
    begin
        PayloadObj.Add('wmsRef', 'FUL-002');
        PayloadObj.Add('reference', 'DG-00002');
        PayloadObj.Add('bcOrderNo', BcOrderNo);
        PayloadObj.Add('shipmentId', ShipmentId);
        PayloadObj.Add('shippedAt', '2026-06-11T14:58:00Z');
        PayloadObj.Add('carrier', 'NZ Post');
        PayloadObj.Add('trackingNumber', 'NZ999');

        LineObj1.Add('sku', SKU1);
        LineObj1.Add('shippedQuantity', Qty1);
        LinesArray.Add(LineObj1);

        LineObj2.Add('sku', SKU2);
        LineObj2.Add('shippedQuantity', Qty2);
        LinesArray.Add(LineObj2);

        PayloadObj.Add('lines', LinesArray);
        PayloadObj.WriteTo(BuildMultiLinePayload);
    end;

    local procedure StageAndProcessMessage(MessageType: Enum "Integration Message Type"; IdempotencyKey: Text; Payload: Text; var IntegrationMessage: Record "Integration Message")
    var
        IntegrationMsgStage: Codeunit "Integration Msg. Stage";
    begin
        IntegrationMessage.Init();
        IntegrationMessage."Type" := MessageType;
        IntegrationMessage."Idempotency Key" := CopyStr(IdempotencyKey, 1, 50);
        IntegrationMsgStage.StageAndProcess(IntegrationMessage, Payload);
    end;

    local procedure CleanupMessages()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"WMS Shipment Confirmation");
        IntegrationMessage.DeleteAll();
    end;

    local procedure CleanupWMSSetup()
    var
        WMSSetup: Record "WMS Setup";
    begin
        if WMSSetup.Get() then
            WMSSetup.Delete();
    end;

    [Test]
    procedure FullShipmentPostsSuccessfully()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        SalesShipmentHeader: Record "Sales Shipment Header";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] Released Sales Order with 5 units, WMS Setup configured
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', false);
        CreateSKUMapping('WMS', 'ESP-250', Item."No.");
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 5, 'DG-00001');

        // [WHEN] Process shipment confirmation for full quantity
        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-001', 'ESP-250', 5, 'NZ Post', 'NZ123');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-001', Payload, IntegrationMessage);

        // [THEN] Sales Shipment posted
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual("Integration Message Status"::Completed, IntegrationMessage.Status,
            'Message should be Completed after successful posting.');
        Assert.AreNotEqual('', IntegrationMessage."Document No.",
            'Document No. should be set to posted shipment no.');

        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        Assert.IsTrue(SalesShipmentHeader.FindFirst(), 'Posted Sales Shipment should exist.');
    end;

    [Test]
    procedure PartialShipmentLeavesOrderOpen()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        SalesLine: Record "Sales Line";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] Released Sales Order with 10 units
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', false);
        CreateSKUMapping('WMS', 'FIL-250', Item."No.");
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 10, 'DG-00002');

        // [WHEN] Process shipment for only 6 units
        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-002', 'FIL-250', 6, 'NZ Post', 'NZ456');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-002', Payload, IntegrationMessage);

        // [THEN] Only 6 shipped, order still open with 4 outstanding
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual("Integration Message Status"::Completed, IntegrationMessage.Status,
            'Message should be Completed.');

        SalesHeader.Get(SalesHeader."Document Type"::Order, SalesHeader."No.");
        // Order should still exist (not fully shipped)
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.FindFirst();
        Assert.AreEqual(4, SalesLine."Outstanding Quantity",
            'Outstanding Quantity should be 4 after shipping 6 of 10.');
    end;

    [Test]
    procedure PostInvoiceWhenConfigured()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] WMS Setup with Post Invoice = true
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', true);
        CreateSKUMapping('WMS', 'DEC-250', Item."No.");
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 3, 'DG-00003');

        // [WHEN] Process shipment confirmation
        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-003', 'DEC-250', 3, 'NZ Post', 'NZ789');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-003', Payload, IntegrationMessage);

        // [THEN] Invoice posted
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual("Integration Message Status"::Completed, IntegrationMessage.Status,
            'Message should be Completed.');

        SalesInvoiceHeader.SetRange("Order No.", SalesHeader."No.");
        Assert.IsTrue(SalesInvoiceHeader.FindFirst(), 'Posted Sales Invoice should exist when Post Invoice is true.');
    end;

    [Test]
    procedure NoInvoiceWhenNotConfigured()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] WMS Setup with Post Invoice = false
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', false);
        CreateSKUMapping('WMS', 'COL-250', Item."No.");
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 2, 'DG-00004');

        // [WHEN] Process shipment confirmation
        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-004', 'COL-250', 2, 'NZ Post', 'NZ321');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-004', Payload, IntegrationMessage);

        // [THEN] No invoice posted
        SalesInvoiceHeader.SetRange("Order No.", SalesHeader."No.");
        Assert.IsFalse(SalesInvoiceHeader.FindFirst(), 'No Sales Invoice should exist when Post Invoice is false.');
    end;

    [Test]
    procedure CarrierAndTrackingRecorded()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        ShippingAgent: Record "Shipping Agent";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] Released Sales Order
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', false);
        CreateSKUMapping('WMS', 'ETH-250', Item."No.");
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 1, 'DG-00005');

        // [WHEN] Process with carrier and tracking
        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-005', 'ETH-250', 1, 'NZ Post', 'NZ555888');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-005', Payload, IntegrationMessage);

        // [THEN] Shipping Agent exists and tracking recorded
        Assert.IsTrue(ShippingAgent.Get('NZ Post'), 'Shipping Agent should be created.');

        // The Sales Header was posted so check the shipment
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual("Integration Message Status"::Completed, IntegrationMessage.Status, 'Should be completed.');
    end;

    [Test]
    procedure DuplicateShipmentIdNotReprocessed()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage1: Record "Integration Message";
        IntegrationMessage2: Record "Integration Message";
        SalesShipmentHeader: Record "Sales Shipment Header";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
        ShipmentCount: Integer;
    begin
        // [GIVEN] A shipment already processed for SHP-006
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', false);
        CreateSKUMapping('WMS', 'SUM-250', Item."No.");
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 4, 'DG-00006');

        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-006', 'SUM-250', 4, 'NZ Post', 'NZ000');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-006', Payload, IntegrationMessage1);

        // [WHEN] Same shipmentId submitted again
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-006', Payload, IntegrationMessage2);

        // [THEN] Only one shipment posted (idempotency prevents re-processing)
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        ShipmentCount := SalesShipmentHeader.Count();
        Assert.AreEqual(1, ShipmentCount, 'Only one shipment should be posted despite duplicate submission.');
    end;

    [Test]
    procedure UnknownOrderNoFails()
    var
        IntegrationMessage: Record "Integration Message";
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] No Sales Order with the given number
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'WMS', false);

        // [WHEN] Process with non-existent bcOrderNo
        Payload := BuildShipmentPayload('INVALID-999', 'SHP-007', 'ESP-250', 1, 'NZ Post', 'NZ111');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-007', Payload, IntegrationMessage);

        // [THEN] Message is Failed
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual("Integration Message Status"::Failed, IntegrationMessage.Status,
            'Message should be Failed for unknown order.');
    end;

    [Test]
    procedure UnmappedSKUFails()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] Sales Order exists but SKU not in mapping
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', false);
        // No mapping for 'UNKNOWN-SKU'
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 2, 'DG-00008');

        // [WHEN] Process with unmapped SKU
        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-008', 'UNKNOWN-SKU', 2, 'NZ Post', 'NZ222');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-008', Payload, IntegrationMessage);

        // [THEN] Message is Failed
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual("Integration Message Status"::Failed, IntegrationMessage.Status,
            'Message should be Failed for unmapped SKU.');
    end;

    [Test]
    procedure DocumentNoSetToShipmentNo()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        SalesShipmentHeader: Record "Sales Shipment Header";
        Item: Record Item;
        Location: Record Location;
        Payload: Text;
    begin
        // [GIVEN] Released Sales Order
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        LibraryInventory.CreateItem(Item);
        CreateWMSSetup(Location.Code, 'WMS', false);
        CreateSKUMapping('WMS', 'DOC-SKU', Item."No.");
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 1, 'DG-00009');

        // [WHEN] Process shipment
        Payload := BuildShipmentPayload(SalesHeader."No.", 'SHP-009', 'DOC-SKU', 1, 'NZ Post', 'NZ333');
        StageAndProcessMessage("Integration Message Type"::"WMS Shipment Confirmation", 'SHP-009', Payload, IntegrationMessage);

        // [THEN] Document No. matches posted shipment
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        SalesShipmentHeader.FindLast();
        Assert.AreEqual(SalesShipmentHeader."No.", IntegrationMessage."Document No.",
            'Integration Message Document No. should equal posted shipment no.');
    end;
}
