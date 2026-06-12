codeunit 73298496 "Webstore Shipment Notify Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";

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
        SalesLine.Validate("Unit Price", 15.0);
        SalesLine.Modify(true);

        ReleaseSalesDoc.PerformManualRelease(SalesHeader);
    end;

    local procedure PostShipment(var SalesHeader: Record "Sales Header")
    var
        SalesPost: Codeunit "Sales-Post";
    begin
        SalesHeader.Ship := true;
        SalesHeader.Invoice := false;
        SalesPost.Run(SalesHeader);
    end;

    local procedure FindNotifyMessage(ExternalDocNo: Code[35]; var IntegrationMessage: Record "Integration Message"): Boolean
    begin
        IntegrationMessage.Reset();
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Webstore Shipment Notify");
        IntegrationMessage.SetRange("Idempotency Key", ExternalDocNo + '-SHIP');
        exit(IntegrationMessage.FindFirst());
    end;

    local procedure CleanupMessages()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Webstore Shipment Notify");
        IntegrationMessage.DeleteAll();
    end;

    [Test]
    procedure ShipmentPostCreatesNotifyMessage()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
    begin
        // [GIVEN] Released Sales Order with External Document No.
        CleanupMessages();
        LibraryInventory.CreateItem(Item);
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 3, 'DG-00010');

        // [WHEN] Post shipment
        PostShipment(SalesHeader);

        // [THEN] Webstore Shipment Notify message created with Completed status
        Assert.IsTrue(FindNotifyMessage('DG-00010', IntegrationMessage),
            'Notification message should be created on shipment posting.');
        Assert.AreEqual("Integration Message Status"::Completed, IntegrationMessage.Status,
            'Message status should be Completed.');
    end;

    [Test]
    procedure PayloadContainsCorrectFields()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        PayloadJson: JsonObject;
        StatusToken: JsonToken;
        BcOrderToken: JsonToken;
        DespatchToken: JsonToken;
    begin
        // [GIVEN] Released Sales Order
        CleanupMessages();
        LibraryInventory.CreateItem(Item);
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 2, 'DG-00011');

        // [WHEN] Post shipment
        PostShipment(SalesHeader);

        // [THEN] Payload has status, bcOrderNo, despatchedAt
        FindNotifyMessage('DG-00011', IntegrationMessage);
        PayloadJson.ReadFrom(IntegrationMessage.GetRequestContent());

        Assert.IsTrue(PayloadJson.Get('status', StatusToken), 'Payload must have status.');
        Assert.AreEqual('Despatched', StatusToken.AsValue().AsText(), 'status should be Despatched.');

        Assert.IsTrue(PayloadJson.Get('bcOrderNo', BcOrderToken), 'Payload must have bcOrderNo.');
        Assert.AreEqual(SalesHeader."No.", BcOrderToken.AsValue().AsText(), 'bcOrderNo should be Sales Order No.');

        Assert.IsTrue(PayloadJson.Get('despatchedAt', DespatchToken), 'Payload must have despatchedAt.');
        Assert.AreNotEqual('', DespatchToken.AsValue().AsText(), 'despatchedAt should not be empty.');
    end;

    [Test]
    procedure NoMessageForOrderWithoutExternalDocNo()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Customer: Record Customer;
        ReleaseSalesDoc: Codeunit "Release Sales Document";
        MessageCountBefore: Integer;
        MessageCountAfter: Integer;
    begin
        // [GIVEN] Released Sales Order WITHOUT External Document No.
        CleanupMessages();
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Webstore Shipment Notify");
        MessageCountBefore := IntegrationMessage.Count();

        LibraryInventory.CreateItem(Item);
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        // Explicitly no External Document No.
        SalesHeader."External Document No." := '';
        SalesHeader.Modify();

        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);
        SalesLine.Validate("Unit Price", 10.0);
        SalesLine.Modify(true);

        ReleaseSalesDoc.PerformManualRelease(SalesHeader);

        // [WHEN] Post shipment
        SalesHeader.Ship := true;
        SalesHeader.Invoice := false;
        Codeunit.Run(Codeunit::"Sales-Post", SalesHeader);

        // [THEN] No notification message created
        IntegrationMessage.Reset();
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Webstore Shipment Notify");
        MessageCountAfter := IntegrationMessage.Count();
        Assert.AreEqual(MessageCountBefore, MessageCountAfter,
            'No notification should be created for orders without External Document No.');
    end;

    [Test]
    procedure DuplicateShipmentNotifyIdempotent()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        IntegrationMessage: Record "Integration Message";
        Item: Record Item;
        Customer: Record Customer;
        ReleaseSalesDoc: Codeunit "Release Sales Document";
        MessageCount: Integer;
    begin
        // [GIVEN] First shipment already created a notify message for DG-00012
        CleanupMessages();
        LibraryInventory.CreateItem(Item);
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 5, 'DG-00012');

        // Ship partially (Qty. to Ship = 3)
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindFirst();
        SalesLine.Validate("Qty. to Ship", 3);
        SalesLine.Modify(true);

        SalesHeader.Ship := true;
        SalesHeader.Invoice := false;
        Codeunit.Run(Codeunit::"Sales-Post", SalesHeader);

        // [WHEN] Ship the remaining 2
        SalesHeader.Get(SalesHeader."Document Type"::Order, SalesHeader."No.");
        SalesHeader.Ship := true;
        SalesHeader.Invoice := false;
        Codeunit.Run(Codeunit::"Sales-Post", SalesHeader);

        // [THEN] Only one notification message (idempotency key prevents duplicate)
        IntegrationMessage.Reset();
        IntegrationMessage.SetRange("Type", "Integration Message Type"::"Webstore Shipment Notify");
        IntegrationMessage.SetRange("Idempotency Key", 'DG-00012-SHIP');
        MessageCount := IntegrationMessage.Count();
        Assert.AreEqual(1, MessageCount,
            'Only one notification message per Webstore order due to idempotency.');
    end;

    [Test]
    procedure DocumentNoSetToShipmentNo()
    var
        SalesHeader: Record "Sales Header";
        IntegrationMessage: Record "Integration Message";
        SalesShipmentHeader: Record "Sales Shipment Header";
        Item: Record Item;
    begin
        // [GIVEN] Released Sales Order
        CleanupMessages();
        LibraryInventory.CreateItem(Item);
        CreateReleasedSalesOrder(SalesHeader, Item."No.", 1, 'DG-00013');

        // [WHEN] Post shipment
        PostShipment(SalesHeader);

        // [THEN] Document No. on message matches posted shipment
        FindNotifyMessage('DG-00013', IntegrationMessage);
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        SalesShipmentHeader.FindLast();
        Assert.AreEqual(SalesShipmentHeader."No.", IntegrationMessage."Document No.",
            'Document No. should be the posted shipment number.');
    end;
}
