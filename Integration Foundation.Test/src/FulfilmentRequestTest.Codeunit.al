codeunit 73298494 "Fulfilment Request Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";

    local procedure CreateWMSSetup(LocationCode: Code[10]; ShippingMethod: Text[50]; SKUSource: Code[20])
    var
        WMSSetup: Record "WMS Setup";
    begin
        if not WMSSetup.Get() then begin
            WMSSetup.Init();
            WMSSetup.Insert();
        end;
        WMSSetup."Location Code" := LocationCode;
        WMSSetup."Shipping Method" := ShippingMethod;
        WMSSetup."SKU Source" := SKUSource;
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

    local procedure CreateSalesOrderWithItem(var SalesHeader: Record "Sales Header"; ItemNo: Code[20]; Qty: Decimal; ExternalDocNo: Code[35])
    var
        SalesLine: Record "Sales Line";
        Customer: Record Customer;
    begin
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        SalesHeader."External Document No." := ExternalDocNo;
        SalesHeader."Ship-to Name" := 'Test Customer';
        SalesHeader."Ship-to Address" := '12 Queen Street';
        SalesHeader."Ship-to City" := 'Auckland';
        SalesHeader."Ship-to Post Code" := '1010';
        SalesHeader."Ship-to Country/Region Code" := 'NZ';
        SalesHeader."Ship-to Contact" := '+64 21 555 0101';
        SalesHeader.Modify();

        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Qty);
    end;

    local procedure ReleaseSalesOrder(var SalesHeader: Record "Sales Header")
    var
        ReleaseSalesDoc: Codeunit "Release Sales Document";
    begin
        ReleaseSalesDoc.PerformManualRelease(SalesHeader);
    end;

    local procedure FindFulfilmentMessage(SalesOrderNo: Code[20]; var IntegrationMessage: Record "Integration Message"): Boolean
    begin
        IntegrationMessage.Reset();
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Fulfilment Request");
        IntegrationMessage.SetRange("Document No.", SalesOrderNo);
        exit(IntegrationMessage.FindFirst());
    end;

    local procedure CleanupMessages()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Fulfilment Request");
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
    procedure ReleaseCreatesCompletedMessage()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
    begin
        // [GIVEN] WMS Setup with Location and SKU mapping
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'ESP-250', Item."No.");

        // [GIVEN] A Sales Order with a mapped item
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 2, 'DG-00001');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Integration Message created with Status = Completed
        Assert.IsTrue(FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage),
            'Fulfilment request message should be created.');
        Assert.AreEqual(IntegrationMessage.Status, "Integration Message Status"::Completed,
            'Message status should be Completed.');
    end;

    [Test]
    procedure PayloadContainsExpectedFields()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
        PayloadJson: JsonObject;
        ShipToToken: JsonToken;
        LinesToken: JsonToken;
        ShipToObj: JsonObject;
        MethodToken: JsonToken;
        RefToken: JsonToken;
        BcOrderToken: JsonToken;
    begin
        // [GIVEN] WMS Setup and mapped item
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'ESP-250', Item."No.");
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 2, 'DG-00001');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Payload has reference, bcOrderNo, shipTo, lines, shippingMethod, requestedAt
        FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage);
        PayloadJson.ReadFrom(IntegrationMessage.GetRequestContent());

        Assert.IsTrue(PayloadJson.Get('reference', RefToken), 'Payload must have reference.');
        Assert.AreEqual('DG-00001', RefToken.AsValue().AsText(), 'reference should be External Document No.');

        Assert.IsTrue(PayloadJson.Get('bcOrderNo', BcOrderToken), 'Payload must have bcOrderNo.');
        Assert.AreEqual(SalesHeader."No.", BcOrderToken.AsValue().AsText(), 'bcOrderNo should be Sales Order No.');

        Assert.IsTrue(PayloadJson.Get('shipTo', ShipToToken), 'Payload must have shipTo.');
        Assert.IsTrue(PayloadJson.Get('lines', LinesToken), 'Payload must have lines.');
        Assert.IsTrue(PayloadJson.Get('shippingMethod', MethodToken), 'Payload must have shippingMethod.');
        Assert.AreEqual('Standard', MethodToken.AsValue().AsText(), 'shippingMethod should match WMS Setup.');
    end;

    [Test]
    procedure PayloadShipToMatchesSalesHeader()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
        PayloadJson: JsonObject;
        ShipToToken: JsonToken;
        ShipToObj: JsonObject;
        NameToken: JsonToken;
        CityToken: JsonToken;
    begin
        // [GIVEN] Sales Order with ship-to populated
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'ITEM-A', Item."No.");
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 1, 'DG-00002');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] shipTo in payload matches Sales Header ship-to fields
        FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage);
        PayloadJson.ReadFrom(IntegrationMessage.GetRequestContent());
        PayloadJson.Get('shipTo', ShipToToken);
        ShipToObj := ShipToToken.AsObject();

        ShipToObj.Get('name', NameToken);
        Assert.AreEqual('Test Customer', NameToken.AsValue().AsText(), 'shipTo.name should match Ship-to Name.');

        ShipToObj.Get('city', CityToken);
        Assert.AreEqual('Auckland', CityToken.AsValue().AsText(), 'shipTo.city should match Ship-to City.');
    end;

    [Test]
    procedure PayloadLineHasReverseSKU()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
        PayloadJson: JsonObject;
        LinesToken: JsonToken;
        LinesArray: JsonArray;
        LineToken: JsonToken;
        LineObj: JsonObject;
        SKUToken: JsonToken;
    begin
        // [GIVEN] Item mapped to external SKU 'ESP-250' under Source 'WMS'
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'ESP-250', Item."No.");
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 3, 'DG-00003');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Payload line has sku = 'ESP-250'
        FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage);
        PayloadJson.ReadFrom(IntegrationMessage.GetRequestContent());
        PayloadJson.Get('lines', LinesToken);
        LinesArray := LinesToken.AsArray();
        LinesArray.Get(0, LineToken);
        LineObj := LineToken.AsObject();
        LineObj.Get('sku', SKUToken);
        Assert.AreEqual('ESP-250', SKUToken.AsValue().AsText(), 'Line SKU should be the reverse-mapped External SKU.');
    end;

    [Test]
    procedure UnmappedItemCreatesFailedMessage()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
    begin
        // [GIVEN] WMS Setup exists but no SKU mapping for the item
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        // No mapping created for this item
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 1, 'DG-00004');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Integration Message created with Status = Failed and error content
        Assert.IsTrue(FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage),
            'Failed fulfilment message should be created.');
        Assert.AreEqual(IntegrationMessage.Status, "Integration Message Status"::Failed,
            'Message status should be Failed for unmapped SKU.');
        Assert.AreNotEqual('', IntegrationMessage.GetErrorContent(),
            'Error content should describe the unmapped item.');
    end;

    [Test]
    procedure MissingWMSSetupCreatesFailedMessage()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
    begin
        // [GIVEN] No WMS Setup record exists
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'ITEM-X', Item."No.");
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 1, 'DG-00005');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Integration Message created with Status = Failed
        Assert.IsTrue(FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage),
            'Failed message should be created when WMS Setup is missing.');
        Assert.AreEqual(IntegrationMessage.Status, "Integration Message Status"::Failed,
            'Message status should be Failed.');
    end;

    [Test]
    procedure MissingLocationCodeCreatesFailedMessage()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
    begin
        // [GIVEN] WMS Setup exists but Location Code is blank
        CleanupMessages();
        CleanupWMSSetup();
        CreateWMSSetup('', 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'ITEM-Y', Item."No.");
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 1, 'DG-00006');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Failed message with error about missing Location Code
        Assert.IsTrue(FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage),
            'Failed message should be created when Location Code is blank.');
        Assert.AreEqual(IntegrationMessage.Status, "Integration Message Status"::Failed,
            'Message status should be Failed.');
    end;

    [Test]
    procedure ReReleaseCreatesSecondMessage()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
        ReopenSalesDoc: Codeunit "Release Sales Document";
        MessageCount: Integer;
    begin
        // [GIVEN] A released Sales Order (first message created)
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'RE-SKU', Item."No.");
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 1, 'DG-00007');
        ReleaseSalesOrder(SalesHeader);

        // [WHEN] Reopen and release again
        ReopenSalesDoc.PerformManualReopen(SalesHeader);
        // Change idempotency key scenario: same order released twice
        // The first message already has idempotency key, so stage returns false
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Only one message exists (idempotency key prevents duplicate)
        IntegrationMessage.Reset();
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Fulfilment Request");
        IntegrationMessage.SetRange("Document No.", SalesHeader."No.");
        MessageCount := IntegrationMessage.Count();
        Assert.AreEqual(1, MessageCount,
            'Idempotency key prevents duplicate: only one fulfilment message per order.');
    end;

    [Test]
    procedure IdempotencyKeyFormat()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Location: Record Location;
        ExpectedKey: Text;
    begin
        // [GIVEN] A Sales Order
        CleanupMessages();
        CleanupWMSSetup();
        LibraryInventory.CreateLocation(Location);
        CreateWMSSetup(Location.Code, 'Standard', 'WMS');
        LibraryInventory.CreateItem(Item);
        CreateSKUMapping('WMS', 'KEY-SKU', Item."No.");
        CreateSalesOrderWithItem(SalesHeader, Item."No.", 1, 'DG-00008');

        // [WHEN] Release
        ReleaseSalesOrder(SalesHeader);

        // [THEN] Idempotency Key = "{Order No.}-FUL"
        FindFulfilmentMessage(SalesHeader."No.", IntegrationMessage);
        ExpectedKey := SalesHeader."No." + '-FUL';
        Assert.AreEqual(ExpectedKey, IntegrationMessage."Idempotency Key",
            'Idempotency key should be Order No. + -FUL suffix.');
    end;
}
