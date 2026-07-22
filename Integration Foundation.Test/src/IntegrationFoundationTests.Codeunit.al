codeunit 73298471 "Integration Foundation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        MessageMgt: Codeunit "Integration Message Mgt.";

    // --- 001: staging, dedup, correlation -----------------------------------

    [Test]
    procedure StageInbound_CreatesOneNewInboundMessage()
    var
        IntegrationMessage: Record "Integration Message";
        MessageId: Guid;
    begin
        // [WHEN] An inbound message is staged
        MessageId := MessageMgt.StageInbound('WebstoreOrder', 'DG-T001', 'DG-T001', '{"orderNo":"DG-T001"}');

        // [THEN] Exactly one inbound, New message exists with the payload and a correlation id
        IntegrationMessage.Get(MessageId);
        Assert.AreEqual(IntegrationMessage.Direction::Inbound, IntegrationMessage.Direction, 'Direction should be Inbound');
        Assert.AreEqual(IntegrationMessage.Status::New, IntegrationMessage.Status, 'Status should be New');
        Assert.AreEqual('DG-T001', IntegrationMessage."Correlation ID", 'Correlation ID should be set');
        Assert.AreEqual('{"orderNo":"DG-T001"}', IntegrationMessage.GetRequest(), 'Request payload should round-trip');
        Assert.AreEqual(IntegrationMessage.Type::WebstoreOrder, IntegrationMessage.Type, 'Type should resolve to WebstoreOrder');
    end;

    [Test]
    procedure StageInbound_EmptyCorrelation_FallsBackToExternalReference()
    var
        IntegrationMessage: Record "Integration Message";
        MessageId: Guid;
    begin
        // [WHEN] A message is staged with no correlation id
        MessageId := MessageMgt.StageInbound('WebstoreOrder', 'DG-T002', '', 'payload');

        // [THEN] The correlation id falls back to the external reference
        IntegrationMessage.Get(MessageId);
        Assert.AreEqual('DG-T002', IntegrationMessage."Correlation ID", 'Correlation ID should fall back to External Reference');
    end;

    [Test]
    procedure StageInbound_Duplicate_ReturnsExistingAndStagesNothing()
    var
        IntegrationMessage: Record "Integration Message";
        FirstId: Guid;
        SecondId: Guid;
    begin
        // [GIVEN] A staged message
        FirstId := MessageMgt.StageInbound('WebstoreOrder', 'DG-T003', 'DG-T003', 'first');

        // [WHEN] The same (External Reference, Type) is staged again
        SecondId := MessageMgt.StageInbound('WebstoreOrder', 'DG-T003', 'DG-T003', 'second');

        // [THEN] The existing message id is returned and only one row exists
        Assert.AreEqual(FirstId, SecondId, 'A re-delivery should return the existing message id');
        IntegrationMessage.SetRange("External Reference", 'DG-T003');
        IntegrationMessage.SetRange(Type, IntegrationMessage.Type::WebstoreOrder);
        Assert.AreEqual(1, IntegrationMessage.Count(), 'A re-delivery should not stage a second row');
        IntegrationMessage.FindFirst();
        Assert.AreEqual('first', IntegrationMessage.GetRequest(), 'The original payload should be retained, not overwritten by the re-delivery');
    end;

    [Test]
    procedure ResolveType_MapsKnownAndUnknown()
    begin
        Assert.AreEqual("Integration Message Type"::WebstoreOrder, MessageMgt.ResolveType('WebstoreOrder'), 'Known type code should resolve');
        Assert.AreEqual("Integration Message Type"::WmsShipmentConfirmation, MessageMgt.ResolveType('WmsShipmentConfirmation'), 'Known type code should resolve');
        Assert.AreEqual("Integration Message Type"::Unknown, MessageMgt.ResolveType('NotARealType'), 'Unknown type code should resolve to Unknown');
    end;

    // --- 001: dispatcher success / failure classification -------------------
    // These mirror the dispatcher's per-message steps (MarkInProgress, Processor.Run,
    // MarkResolved/Fail) without the Job Queue Commit, which is not allowed in tests.

    [Test]
    procedure Dispatch_Success_ResolvesMessage()
    var
        IntegrationMessage: Record "Integration Message";
        Processor: Codeunit "Integration Msg. Processor";
        MessageId: Guid;
    begin
        // [GIVEN] A New message routed to a succeeding handler
        MessageId := MessageMgt.StageInbound('TestSucceed', 'T-S1', 'T-S1', '{}');
        IntegrationMessage.Get(MessageId);
        MessageMgt.MarkInProgress(IntegrationMessage);

        // [WHEN] The processor runs the handler successfully
        Assert.IsTrue(Processor.Run(IntegrationMessage), 'Processor should succeed');
        IntegrationMessage.Get(MessageId);
        MessageMgt.MarkResolved(IntegrationMessage);

        // [THEN] The message is Resolved with the handler's document anchor
        Assert.AreEqual(IntegrationMessage.Status::Resolved, IntegrationMessage.Status, 'Status should be Resolved');
        Assert.AreEqual('TEST-OK', IntegrationMessage."Document No.", 'Handler should set Document No.');
    end;

    [Test]
    procedure Dispatch_PermanentError_FailsWithoutRetry()
    var
        IntegrationMessage: Record "Integration Message";
        Processor: Codeunit "Integration Msg. Processor";
        MessageId: Guid;
        ErrorText: Text;
    begin
        // [GIVEN] A New message routed to a permanently-failing handler
        MessageId := MessageMgt.StageInbound('TestFailPermanent', 'T-P1', 'T-P1', '{}');
        IntegrationMessage.Get(MessageId);
        MessageMgt.MarkInProgress(IntegrationMessage);

        // [WHEN] The processor runs and the handler raises a permanent error
        ClearLastError();
        Assert.IsFalse(Processor.Run(IntegrationMessage), 'Processor should fail');
        ErrorText := GetLastErrorText();
        IntegrationMessage.Get(MessageId);
        MessageMgt.Fail(IntegrationMessage, ErrorText);

        // [THEN] The message Fails Permanent and is not retried
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Status should be Failed');
        Assert.AreEqual(IntegrationMessage."Error Class"::Permanent, IntegrationMessage."Error Class", 'Error Class should be Permanent');
        Assert.AreEqual(0, IntegrationMessage."Retry Count", 'Permanent failures should not increment Retry Count');
        Assert.AreNotEqual('', IntegrationMessage."Error Message", 'Error message should be recorded');
    end;

    [Test]
    procedure Dispatch_TransientError_RequeuesWithRetry()
    var
        IntegrationMessage: Record "Integration Message";
        Processor: Codeunit "Integration Msg. Processor";
        MessageId: Guid;
        ErrorText: Text;
    begin
        // [GIVEN] A New message routed to a transiently-failing handler
        MessageId := MessageMgt.StageInbound('TestFailTransient', 'T-X1', 'T-X1', '{}');
        IntegrationMessage.Get(MessageId);
        MessageMgt.MarkInProgress(IntegrationMessage);

        // [WHEN] The processor runs and the handler raises a plain (transient) error
        ClearLastError();
        Assert.IsFalse(Processor.Run(IntegrationMessage), 'Processor should fail');
        ErrorText := GetLastErrorText();
        IntegrationMessage.Get(MessageId);
        MessageMgt.Fail(IntegrationMessage, ErrorText);

        // [THEN] The message is re-queued (New) with the retry count incremented
        Assert.AreEqual(IntegrationMessage.Status::New, IntegrationMessage.Status, 'Transient failure should re-queue to New');
        Assert.AreEqual(IntegrationMessage."Error Class"::Transient, IntegrationMessage."Error Class", 'Error Class should be Transient');
        Assert.AreEqual(1, IntegrationMessage."Retry Count", 'Transient failure should increment Retry Count');
    end;

    [Test]
    procedure Dispatch_UnknownType_FailsPermanent()
    var
        IntegrationMessage: Record "Integration Message";
        Processor: Codeunit "Integration Msg. Processor";
        MessageId: Guid;
        ErrorText: Text;
    begin
        // [GIVEN] A New message whose type code does not resolve to a handler
        MessageId := MessageMgt.StageInbound('NoSuchType', 'U-1', 'U-1', '{}');
        IntegrationMessage.Get(MessageId);
        MessageMgt.MarkInProgress(IntegrationMessage);

        // [WHEN] The processor runs the Unknown handler
        ClearLastError();
        Assert.IsFalse(Processor.Run(IntegrationMessage), 'Unknown handler should fail');
        ErrorText := GetLastErrorText();
        IntegrationMessage.Get(MessageId);
        MessageMgt.Fail(IntegrationMessage, ErrorText);

        // [THEN] The message Fails Permanent (a no-handler is not retried forever)
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Unknown type should Fail');
        Assert.AreEqual(IntegrationMessage."Error Class"::Permanent, IntegrationMessage."Error Class", 'No handler is a Permanent failure');
    end;

    // --- 002: manual resolution actions -------------------------------------

    [Test]
    procedure Resolution_Resolve_RequeuesSameMessageId()
    var
        IntegrationMessage: Record "Integration Message";
        ResolutionMgt: Codeunit "Integration Resolution Mgt.";
        OriginalId: Guid;
    begin
        // [GIVEN] A Failed message
        IntegrationMessage.Get(StageFailed('R-1'));
        OriginalId := IntegrationMessage."Message ID";

        // [WHEN] Operations resolves it
        ResolutionMgt.Resolve(IntegrationMessage);

        // [THEN] It returns to New, the error is cleared, and the id is unchanged
        Assert.AreEqual(IntegrationMessage.Status::New, IntegrationMessage.Status, 'Resolve should re-queue to New');
        Assert.AreEqual('', IntegrationMessage."Error Message", 'Resolve should clear the error');
        Assert.AreEqual(OriginalId, IntegrationMessage."Message ID", 'Resolve must keep the same Message ID');
    end;

    [Test]
    procedure Resolution_ConfirmByException_ResolvesAndKeepsAudit()
    var
        IntegrationMessage: Record "Integration Message";
        ResolutionMgt: Codeunit "Integration Resolution Mgt.";
        RetryBefore: Integer;
    begin
        // [GIVEN] a Failed message with an error recorded
        IntegrationMessage.Get(StageFailed('R-2'));
        RetryBefore := IntegrationMessage."Retry Count";

        // [WHEN] Operations confirms it by exception
        ResolutionMgt.ConfirmByException(IntegrationMessage);

        // [THEN] It is Resolved, retry unchanged, error preserved for audit
        Assert.AreEqual(IntegrationMessage.Status::Resolved, IntegrationMessage.Status, 'Confirm should Resolve');
        Assert.AreEqual(RetryBefore, IntegrationMessage."Retry Count", 'Confirm should not change Retry Count');
        Assert.AreNotEqual('', IntegrationMessage."Error Message", 'Confirm should preserve the error for audit');
    end;

    [Test]
    procedure Resolution_Reassign_ReroutesAndRequeues()
    var
        IntegrationMessage: Record "Integration Message";
        ResolutionMgt: Codeunit "Integration Resolution Mgt.";
    begin
        // [GIVEN] a Failed message staged under a type code that did not resolve
        IntegrationMessage.Get(StageFailedWithType('WrongType', 'RA-1'));
        Assert.AreEqual(IntegrationMessage.Type::Unknown, IntegrationMessage.Type, 'Precondition: type should be Unknown');

        // [WHEN] ops corrects the type code and reassigns
        IntegrationMessage."Type Code" := 'WebstoreOrder';
        ResolutionMgt.Reassign(IntegrationMessage);

        // [THEN] the type is re-resolved and the message is re-queued, error cleared
        Assert.AreEqual(IntegrationMessage.Type::WebstoreOrder, IntegrationMessage.Type, 'Reassign should re-resolve the type');
        Assert.AreEqual(IntegrationMessage.Status::New, IntegrationMessage.Status, 'Reassign should re-queue to New');
        Assert.AreEqual('', IntegrationMessage."Error Message", 'Reassign should clear the error');
    end;

    [Test]
    procedure Resolution_GuardsNonFailedMessage()
    var
        IntegrationMessage: Record "Integration Message";
        ResolutionMgt: Codeunit "Integration Resolution Mgt.";
    begin
        // [GIVEN] a New (not Failed) message
        IntegrationMessage.Get(MessageMgt.StageInbound('WebstoreOrder', 'R-3', 'R-3', '{}'));

        // [WHEN/THEN] Resolve is rejected with the guard error, not just any error
        asserterror ResolutionMgt.Resolve(IntegrationMessage);
        Assert.ExpectedError('Only a Failed message can be resolved');
    end;

    // --- 001: transient retry budget boundary -------------------------------

    [Test]
    procedure Dispatch_TransientPastBudget_Fails()
    var
        IntegrationMessage: Record "Integration Message";
        MessageId: Guid;
    begin
        // [GIVEN] a message already at the default retry budget (3)
        MessageId := MessageMgt.StageInbound('WebstoreOrder', 'T-X9', 'T-X9', '{}');
        IntegrationMessage.Get(MessageId);
        IntegrationMessage."Retry Count" := 3;
        IntegrationMessage.Modify();

        // [WHEN] another transient failure is recorded
        MessageMgt.Fail(IntegrationMessage, MessageMgt.CreateTransientError('still failing'));

        // [THEN] it stops retrying and lands Failed without exceeding the budget
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Transient past the budget should Fail, not re-queue');
        Assert.AreEqual(3, IntegrationMessage."Retry Count", 'Retry Count should not exceed the budget');
    end;

    // --- 001: outbound staging + idempotency guard --------------------------

    [Test]
    procedure StageOutbound_ParksAwaitingReplyAndIsFound()
    var
        IntegrationMessage: Record "Integration Message";
        MessageId: Guid;
    begin
        // [GIVEN] no outbound fulfilment for the reference yet
        Assert.IsFalse(MessageMgt.OutboundExists('FulfilmentRequest', 'DG-OB1'), 'No outbound should exist before staging');

        // [WHEN] an outbound message is staged
        MessageId := MessageMgt.StageOutbound('FulfilmentRequest', 'DG-OB1', 'DG-OB1', 'S-ORD-OB1', '{}');

        // [THEN] it parks Awaiting Reply with its document anchor and is now found
        IntegrationMessage.Get(MessageId);
        Assert.AreEqual(IntegrationMessage.Direction::Outbound, IntegrationMessage.Direction, 'Direction should be Outbound');
        Assert.AreEqual(IntegrationMessage.Status::"Awaiting Reply", IntegrationMessage.Status, 'Outbound should park Awaiting Reply');
        Assert.AreEqual('S-ORD-OB1', IntegrationMessage."Document No.", 'Document No. should be stored');
        Assert.IsTrue(MessageMgt.OutboundExists('FulfilmentRequest', 'DG-OB1'), 'OutboundExists should find the staged message');
        Assert.AreEqual(MessageId, MessageMgt.FindOutboundParent('FulfilmentRequest', 'DG-OB1'), 'FindOutboundParent should return the staged message id');
    end;

    // --- 003: SKU mapping lookups -------------------------------------------

    [Test]
    procedure SkuMapping_ForwardHitReverseHitAndMiss()
    var
        SKUMapping: Record "Integration SKU Mapping";
        SKUMgt: Codeunit "Integration SKU Mgt.";
        ResolvedSKU: Code[20];
    begin
        // [GIVEN] a mapping from ESP-250 to item 1000
        SKUMapping.Init();
        SKUMapping.SKU := 'ESP-250';
        SKUMapping."Item No." := '1000';
        SKUMapping.Insert();

        // [THEN] forward hit returns the mapping
        Assert.IsTrue(SKUMgt.TryGetMapping('ESP-250', SKUMapping), 'Forward lookup should hit');
        Assert.AreEqual('1000', SKUMapping."Item No.", 'Forward lookup should return the item');

        // [THEN] reverse hit returns the SKU
        Assert.IsTrue(SKUMgt.TryGetSKU('1000', '', ResolvedSKU), 'Reverse lookup should hit');
        Assert.AreEqual('ESP-250', ResolvedSKU, 'Reverse lookup should return the SKU');

        // [THEN] forward miss returns false and the clear-error variant errors
        Assert.IsFalse(SKUMgt.TryGetMapping('ZZZ-999', SKUMapping), 'Forward lookup should miss for an unmapped SKU');
        asserterror SKUMgt.GetMapping('ZZZ-999', SKUMapping);
        Assert.ExpectedError('ZZZ-999');
    end;

    // --- 008: subscription health monitor -----------------------------------

    [Test]
    procedure Monitor_MissingSubscription_RaisesOneAlert()
    var
        ExpectedSubscription: Record "Integration Expected Subscr.";
        Monitor: Codeunit "Subscription Health Monitor";
        Spy: Codeunit "Test Subscription Spy";
        LiveKeys: List of [Text];
    begin
        // [GIVEN] two expected subscriptions, one of which is live
        InsertExpected('OnSalesOrderReleased_v1', 'https://live/ok');
        InsertExpected('OnShipmentConfirmed_v1', 'https://gone/missing');
        LiveKeys.Add(Monitor.SubscriptionKey('OnSalesOrderReleased_v1', 'https://live/ok'));

        Spy.ResetSpy();
        Spy.SetLive(LiveKeys);
        BindSubscription(Spy);

        // [WHEN] the monitor checks health
        Monitor.CheckHealth();
        UnbindSubscription(Spy);

        // [THEN] exactly one missing-subscription alert is raised (the absent one)
        Assert.AreEqual(1, Spy.GetMissingCount(), 'Exactly the missing subscription should alert');
    end;

    [Test]
    procedure Monitor_AllPresent_RaisesNoAlert()
    var
        Monitor: Codeunit "Subscription Health Monitor";
        Spy: Codeunit "Test Subscription Spy";
        LiveKeys: List of [Text];
    begin
        // [GIVEN] one expected subscription that is live
        InsertExpected('OnSalesOrderReleased_v1', 'https://live/ok');
        LiveKeys.Add(Monitor.SubscriptionKey('OnSalesOrderReleased_v1', 'https://live/ok'));

        Spy.ResetSpy();
        Spy.SetLive(LiveKeys);
        BindSubscription(Spy);

        // [WHEN] the monitor checks health
        Monitor.CheckHealth();
        UnbindSubscription(Spy);

        // [THEN] no alert is raised
        Assert.AreEqual(0, Spy.GetMissingCount(), 'No alert should be raised when all are present');
    end;

    // --- helpers ------------------------------------------------------------

    local procedure StageFailed(ExternalRef: Text[100]): Guid
    begin
        exit(StageFailedWithType('WebstoreOrder', ExternalRef));
    end;

    local procedure StageFailedWithType(TypeCode: Text; ExternalRef: Text[100]): Guid
    var
        IntegrationMessage: Record "Integration Message";
        MessageId: Guid;
    begin
        MessageId := MessageMgt.StageInbound(TypeCode, ExternalRef, ExternalRef, '{}');
        IntegrationMessage.Get(MessageId);
        MessageMgt.MarkInProgress(IntegrationMessage);
        MessageMgt.Fail(IntegrationMessage, MessageMgt.CreatePermanentError('Seeded failure for resolution test'));
        exit(MessageId);
    end;

    local procedure InsertExpected(EventName: Text[100]; NotificationUrl: Text[250])
    var
        ExpectedSubscription: Record "Integration Expected Subscr.";
    begin
        ExpectedSubscription.Init();
        ExpectedSubscription."Event Name" := EventName;
        ExpectedSubscription."Notification URL" := NotificationUrl;
        ExpectedSubscription.Insert();
    end;
}
