codeunit 73298493 "Webstore Order Ingest Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryUtility: Codeunit "Library - Utility";
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";

    local procedure CreateWebstoreSetup(var CustomerNo: Code[20]; var LocationCode: Code[10])
    var
        WebstoreSetup: Record "Webstore Setup";
        Customer: Record Customer;
        Location: Record Location;
    begin
        LibrarySales.CreateCustomer(Customer);
        CustomerNo := Customer."No.";

        LibraryInventory.CreateLocation(Location);
        LocationCode := Location.Code;

        if not WebstoreSetup.Get() then begin
            WebstoreSetup.Init();
            WebstoreSetup.Insert();
        end;
        WebstoreSetup."Customer No." := CustomerNo;
        WebstoreSetup."Location Code" := LocationCode;
        WebstoreSetup.Modify();
    end;

    local procedure CreateSKUMapping(ExternalSKU: Code[50]; ItemNo: Code[20])
    var
        IntegrationSKUMapping: Record "Integration SKU Mapping";
    begin
        IntegrationSKUMapping.Init();
        IntegrationSKUMapping.Source := 'WEBSTORE';
        IntegrationSKUMapping."External SKU" := ExternalSKU;
        IntegrationSKUMapping."Item No." := ItemNo;
        if not IntegrationSKUMapping.Insert() then
            IntegrationSKUMapping.Modify();
    end;

    local procedure CreateItem(var ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItem(Item);
        ItemNo := Item."No.";
    end;

    local procedure BuildOrderJson(OrderNo: Text; SKU: Text; Qty: Integer; UnitPrice: Decimal): Text
    begin
        exit(StrSubstNo(
            '{"orderNo":"%1","placedAt":"2026-06-11T09:14:00.000Z","currency":"NZD",' +
            '"customer":{"name":"Test Shopper","email":"test@example.com","phone":"+64 21 555 0101",' +
            '"address":{"line1":"12 Queen Street","line2":"","city":"Auckland","postcode":"1010","country":"NZ"}},' +
            '"lines":[{"sku":"%2","name":"Test Item","quantity":%3,"unitPrice":%4}],' +
            '"totalAmount":%5}',
            OrderNo, SKU, Qty, UnitPrice, Qty * UnitPrice));
    end;

    local procedure BuildMultiLineOrderJson(OrderNo: Text; SKU1: Text; Qty1: Integer; Price1: Decimal; SKU2: Text; Qty2: Integer; Price2: Decimal): Text
    begin
        exit(StrSubstNo(
            '{"orderNo":"%1","placedAt":"2026-06-11T09:14:00.000Z","currency":"NZD",' +
            '"customer":{"name":"Test Shopper","email":"test@example.com","phone":"+64 21 555 0101",' +
            '"address":{"line1":"12 Queen Street","line2":"","city":"Auckland","postcode":"1010","country":"NZ"}},' +
            '"lines":[' +
            '{"sku":"%2","name":"Item 1","quantity":%3,"unitPrice":%4},' +
            '{"sku":"%5","name":"Item 2","quantity":%6,"unitPrice":%7}' +
            '],"totalAmount":%8}',
            OrderNo, SKU1, Qty1, Price1, SKU2, Qty2, Price2, (Qty1 * Price1) + (Qty2 * Price2)));
    end;

    local procedure StageAndProcess(RequestContent: Text; IdempotencyKey: Text[50]; var IntegrationMessage: Record "Integration Message")
    var
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
    begin
        IntegrationMessage.Init();
        IntegrationMessage."Type" := IntegrationMessage."Type"::"Webstore Order";
        IntegrationMessage."Idempotency Key" := IdempotencyKey;
        IntegrationMessage.SetRequestContent(RequestContent);
        IntegrationMessage.Insert(true);
        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);
        IntegrationMessage.Get(IntegrationMessage."Message ID");
    end;

    [Test]
    procedure ValidOrder_CreatesSalesOrder()
    var
        IntegrationMessage: Record "Integration Message";
        SalesHeader: Record "Sales Header";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        ItemNo: Code[20];
        OrderNo: Text;
    begin
        // [SCENARIO] Valid Webstore order creates Sales Order with correct Customer, Location, and External Document No.

        // [GIVEN] Setup and mapping exist
        CreateWebstoreSetup(CustomerNo, LocationCode);
        CreateItem(ItemNo);
        CreateSKUMapping('ESP-250', ItemNo);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Order is staged and processed
        StageAndProcess(BuildOrderJson(OrderNo, 'ESP-250', 2, 18.50), CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Sales Order is created
        Assert.AreEqual(IntegrationMessage.Status::Completed, IntegrationMessage.Status, 'Message should be Completed.');
        Assert.AreNotEqual('', IntegrationMessage."Document No.", 'Document No. should be set to BC Sales Order No.');

        SalesHeader.Get(SalesHeader."Document Type"::Order, IntegrationMessage."Document No.");
        Assert.AreEqual(CustomerNo, SalesHeader."Sell-to Customer No.", 'Sell-to Customer should be from setup.');
        Assert.AreEqual(OrderNo, SalesHeader."External Document No.", 'External Document No. should be the Webstore order number.');
    end;

    [Test]
    procedure MultiLineOrder_CreatesMultipleSalesLines()
    var
        IntegrationMessage: Record "Integration Message";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        ItemNo1: Code[20];
        ItemNo2: Code[20];
        OrderNo: Text;
    begin
        // [SCENARIO] Multi-line order creates one Sales Line per order line

        // [GIVEN] Setup and two item mappings
        CreateWebstoreSetup(CustomerNo, LocationCode);
        CreateItem(ItemNo1);
        CreateItem(ItemNo2);
        CreateSKUMapping('FIL-250', ItemNo1);
        CreateSKUMapping('DEC-250', ItemNo2);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Multi-line order is processed
        StageAndProcess(
            BuildMultiLineOrderJson(OrderNo, 'FIL-250', 1, 17.00, 'DEC-250', 3, 18.00),
            CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Two sales lines exist
        SalesHeader.Get(SalesHeader."Document Type"::Order, IntegrationMessage."Document No.");
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        Assert.AreEqual(2, SalesLine.Count(), 'Should have 2 sales lines.');

        SalesLine.FindFirst();
        Assert.AreEqual(ItemNo1, SalesLine."No.", 'First line item should be correct.');
        Assert.AreEqual(1, SalesLine.Quantity, 'First line quantity should be 1.');
        Assert.AreEqual(17.00, SalesLine."Unit Price", 'First line unit price should be 17.00.');
    end;

    [Test]
    procedure SKUMapped_ResolvesCorrectItem()
    var
        IntegrationMessage: Record "Integration Message";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        ItemNo: Code[20];
        OrderNo: Text;
    begin
        // [SCENARIO] Mapped SKU resolves to correct BC Item No.

        // [GIVEN] A specific item mapped to SKU "COL-250"
        CreateWebstoreSetup(CustomerNo, LocationCode);
        CreateItem(ItemNo);
        CreateSKUMapping('COL-250', ItemNo);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Order with that SKU is processed
        StageAndProcess(BuildOrderJson(OrderNo, 'COL-250', 1, 21.00), CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Sales Line has the mapped Item No.
        SalesHeader.Get(SalesHeader."Document Type"::Order, IntegrationMessage."Document No.");
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindFirst();
        Assert.AreEqual(ItemNo, SalesLine."No.", 'Item No. should be the mapped value.');
    end;

    [Test]
    procedure UnmappedSKU_ProcessingFails()
    var
        IntegrationMessage: Record "Integration Message";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        OrderNo: Text;
    begin
        // [SCENARIO] Unmapped SKU fails processing with clear error

        // [GIVEN] Setup exists but no mapping for "UNKNOWN-SKU"
        CreateWebstoreSetup(CustomerNo, LocationCode);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Order with unmapped SKU is processed
        StageAndProcess(BuildOrderJson(OrderNo, 'UNKNOWN-SKU', 1, 10.00), CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Message is Failed with error naming the SKU
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Should be Failed for unmapped SKU.');
        Assert.IsTrue(IntegrationMessage.GetErrorContent().Contains('UNKNOWN-SKU'), 'Error should name the unmapped SKU.');
    end;

    [Test]
    procedure DuplicateOrderNo_NoSecondSalesOrder()
    var
        IntegrationMessage: Record "Integration Message";
        SecondMessage: Record "Integration Message";
        IntegrationMsgStage: Codeunit "Integration Msg. Stage";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        ItemNo: Code[20];
        OrderNo: Text;
        IdempotencyKey: Text[50];
        IsNew: Boolean;
    begin
        // [SCENARIO] Same order number delivered twice does not create a second Sales Order

        // [GIVEN] A successfully processed order
        CreateWebstoreSetup(CustomerNo, LocationCode);
        CreateItem(ItemNo);
        CreateSKUMapping('ESP-250', ItemNo);
        OrderNo := LibraryUtility.GenerateGUID();
        IdempotencyKey := CopyStr(OrderNo, 1, 50);
        StageAndProcess(BuildOrderJson(OrderNo, 'ESP-250', 2, 18.50), IdempotencyKey, IntegrationMessage);
        Assert.AreEqual(IntegrationMessage.Status::Completed, IntegrationMessage.Status, 'Precondition: first order should succeed.');

        // [WHEN] Same idempotency key is staged again
        SecondMessage.Init();
        SecondMessage."Type" := SecondMessage."Type"::"Webstore Order";
        SecondMessage."Idempotency Key" := IdempotencyKey;
        IsNew := IntegrationMsgStage.StageMessage(SecondMessage, BuildOrderJson(OrderNo, 'ESP-250', 2, 18.50));

        // [THEN] No new message, existing one returned
        Assert.IsFalse(IsNew, 'Second delivery should not create a new message.');
        Assert.AreEqual(IntegrationMessage."Message ID", SecondMessage."Message ID", 'Should return the original message.');
    end;

    [Test]
    procedure ProcessedOrder_SetsDocumentNo()
    var
        IntegrationMessage: Record "Integration Message";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        ItemNo: Code[20];
        OrderNo: Text;
    begin
        // [SCENARIO] Processed order sets Integration Message Document No. to BC Sales Order No.

        // [GIVEN] Valid order
        CreateWebstoreSetup(CustomerNo, LocationCode);
        CreateItem(ItemNo);
        CreateSKUMapping('ESP-250', ItemNo);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Processed
        StageAndProcess(BuildOrderJson(OrderNo, 'ESP-250', 1, 18.50), CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Document No. is set
        Assert.AreNotEqual('', IntegrationMessage."Document No.", 'Document No. should be the BC Sales Order number.');
    end;

    [Test]
    procedure MissingSetupCustomer_ProcessingFails()
    var
        IntegrationMessage: Record "Integration Message";
        WebstoreSetup: Record "Webstore Setup";
        ItemNo: Code[20];
        OrderNo: Text;
    begin
        // [SCENARIO] Missing Customer No. in setup fails with clear error

        // [GIVEN] Setup with no Customer No.
        if not WebstoreSetup.Get() then begin
            WebstoreSetup.Init();
            WebstoreSetup.Insert();
        end;
        WebstoreSetup."Customer No." := '';
        WebstoreSetup.Modify();

        CreateItem(ItemNo);
        CreateSKUMapping('ESP-250', ItemNo);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Order is processed
        StageAndProcess(BuildOrderJson(OrderNo, 'ESP-250', 1, 18.50), CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Message is Failed with setup error
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Should fail on missing setup.');
        Assert.IsTrue(IntegrationMessage.GetErrorContent().Contains('Customer No.'), 'Error should mention Customer No.');
    end;

    [Test]
    procedure ShipToAddress_PopulatedFromPayload()
    var
        IntegrationMessage: Record "Integration Message";
        SalesHeader: Record "Sales Header";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        ItemNo: Code[20];
        OrderNo: Text;
    begin
        // [SCENARIO] Ship-to fields populated from order JSON address

        // [GIVEN] Valid order with address
        CreateWebstoreSetup(CustomerNo, LocationCode);
        CreateItem(ItemNo);
        CreateSKUMapping('ESP-250', ItemNo);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Processed
        StageAndProcess(BuildOrderJson(OrderNo, 'ESP-250', 1, 18.50), CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Ship-to fields set
        SalesHeader.Get(SalesHeader."Document Type"::Order, IntegrationMessage."Document No.");
        Assert.AreEqual('Test Shopper', SalesHeader."Ship-to Name", 'Ship-to Name from payload.');
        Assert.AreEqual('12 Queen Street', SalesHeader."Ship-to Address", 'Ship-to Address from payload.');
        Assert.AreEqual('Auckland', SalesHeader."Ship-to City", 'Ship-to City from payload.');
        Assert.AreEqual('1010', SalesHeader."Ship-to Post Code", 'Ship-to Post Code from payload.');
        Assert.AreEqual('NZ', SalesHeader."Ship-to Country/Region Code", 'Ship-to Country from payload.');
    end;

    [Test]
    procedure PostingDate_SetFromPlacedAt()
    var
        IntegrationMessage: Record "Integration Message";
        SalesHeader: Record "Sales Header";
        CustomerNo: Code[20];
        LocationCode: Code[10];
        ItemNo: Code[20];
        OrderNo: Text;
    begin
        // [SCENARIO] Posting Date set from placedAt timestamp

        // [GIVEN] Order with placedAt = 2026-06-11
        CreateWebstoreSetup(CustomerNo, LocationCode);
        CreateItem(ItemNo);
        CreateSKUMapping('ESP-250', ItemNo);
        OrderNo := LibraryUtility.GenerateGUID();

        // [WHEN] Processed
        StageAndProcess(BuildOrderJson(OrderNo, 'ESP-250', 1, 18.50), CopyStr(OrderNo, 1, 50), IntegrationMessage);

        // [THEN] Posting Date is 2026-06-11
        SalesHeader.Get(SalesHeader."Document Type"::Order, IntegrationMessage."Document No.");
        Assert.AreEqual(20260611D, SalesHeader."Posting Date", 'Posting Date should be from placedAt.');
    end;
}
