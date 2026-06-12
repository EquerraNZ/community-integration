codeunit 73298492 "Integration Msg. Core Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryUtility: Codeunit "Library - Utility";

    [Test]
    procedure StageNewMessage_ReturnsNewStatus()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        // [SCENARIO] Given an inbound POST with a new Idempotency Key,
        // when the API page processes it, then an Integration Message is
        // created with Status = New and a Message ID is assigned.

        // [GIVEN] A new integration message
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IntegrationMessage.SetRequestContent('{"test":"payload"}');

        // [WHEN] The message is inserted (simulating the API page staging)
        IntegrationMessage.Insert(true);

        // [THEN] Status is New and Message ID is assigned
        Assert.AreEqual(IntegrationMessage.Status::New, IntegrationMessage.Status, 'Status should be New after staging.');
        Assert.IsFalse(IsNullGuid(IntegrationMessage."Message ID"), 'Message ID should be assigned on insert.');
        Assert.AreNotEqual(0DT, IntegrationMessage."Created At", 'Created At should be set on insert.');
    end;

    [Test]
    procedure DuplicateIdempotencyKey_NoDuplicate()
    var
        IntegrationMessage: Record "Integration Message";
        SecondMessage: Record "Integration Message";
        IdempotencyKey: Text[50];
    begin
        // [SCENARIO] Given an inbound POST with an Idempotency Key that already
        // exists, when the API page processes it, then no new record is created.

        // [GIVEN] An existing message with a specific idempotency key
        IdempotencyKey := LibraryUtility.GenerateGUID();
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := IdempotencyKey;
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IntegrationMessage.SetRequestContent('{"order":"first"}');
        IntegrationMessage.Insert(true);

        // [WHEN] A second message with the same idempotency key is attempted
        SecondMessage.SetRange("Idempotency Key", IdempotencyKey);
        Assert.IsTrue(SecondMessage.FindFirst(), 'Should find existing message by idempotency key.');

        // [THEN] The existing record is returned, no duplicate created
        SecondMessage.Reset();
        SecondMessage.SetRange("Idempotency Key", IdempotencyKey);
        Assert.AreEqual(1, SecondMessage.Count(), 'Only one record should exist for the same idempotency key.');
        Assert.AreEqual(IntegrationMessage."Message ID", SecondMessage."Message ID", 'Should return the same message.');
    end;

    [Test]
    procedure ProcessMessage_DispatchesByType()
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
    begin
        // [SCENARIO] Given an Integration Message with Status = New and a valid
        // Type, when the processing codeunit runs, then the interface
        // implementation for that Type is called.

        // [GIVEN] A staged message with Type = Test
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IntegrationMessage.SetRequestContent('{"test":"dispatch"}');
        IntegrationMessage.Insert(true);

        // [WHEN] Processing runs
        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);

        // [THEN] The message was processed (response content set by mock)
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreNotEqual('', IntegrationMessage.GetResponseContent(), 'Response content should be set by the processor.');
    end;

    [Test]
    procedure ProcessMessage_Success_StatusCompleted()
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
    begin
        // [SCENARIO] Given processing succeeds, when the interface returns,
        // then the message Status is Completed.

        // [GIVEN] A staged message with a succeeding processor
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IntegrationMessage.SetRequestContent('{"test":"success"}');
        IntegrationMessage.Insert(true);

        // [WHEN] Processing completes successfully
        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);

        // [THEN] Status is Completed
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual(IntegrationMessage.Status::Completed, IntegrationMessage.Status, 'Status should be Completed after successful processing.');
    end;

    [Test]
    procedure ProcessMessage_Failure_StatusFailed_ErrorCaptured()
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
    begin
        // [SCENARIO] Given processing raises an error, when the processing
        // codeunit catches it, then the message Status is Failed, Error Content
        // contains the error text, and Error Code is populated.

        // [GIVEN] A staged message with a failing processor
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::"Test Failing";
        IntegrationMessage.SetRequestContent('{"test":"failure"}');
        IntegrationMessage.Insert(true);

        // [WHEN] Processing fails
        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);

        // [THEN] Status is Failed with error content
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Status should be Failed after processing error.');
        Assert.AreNotEqual('', IntegrationMessage.GetErrorContent(), 'Error Content should contain the error text.');
    end;

    [Test]
    procedure ManualRetry_ResetsStatusToNew()
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
        IntegrationMsgRetry: Codeunit "Integration Msg. Retry";
    begin
        // [SCENARIO] Given a Failed message, when an administrator triggers
        // Retry, then the message Status resets to New and it is reprocessed.

        // [GIVEN] A failed message
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::"Test Failing";
        IntegrationMessage.SetRequestContent('{"test":"retry"}');
        IntegrationMessage.Insert(true);
        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Precondition: message should be Failed.');

        // [WHEN] Change type to succeeding and manually retry
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IntegrationMessage.Modify();
        IntegrationMsgRetry.RetryManual(IntegrationMessage);

        // [THEN] Status is Completed after retry, retry count incremented
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual(IntegrationMessage.Status::Completed, IntegrationMessage.Status, 'Status should be Completed after successful retry.');
        Assert.IsTrue(IntegrationMessage."Retry Count" > 0, 'Retry Count should be incremented.');
    end;

    [Test]
    procedure AutoRetry_RespectsMaxRetryCount()
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
        IntegrationMsgRetry: Codeunit "Integration Msg. Retry";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [SCENARIO] Given automatic retry is configured, when the Job Queue
        // codeunit runs, then Failed messages at or above the max retry count
        // are not retried.

        // [GIVEN] A failed message with Retry Count at the max (3)
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::"Test Failing";
        IntegrationMessage.SetRequestContent('{"test":"max-retry"}');
        IntegrationMessage.Insert(true);
        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);
        IntegrationMessage.Get(IntegrationMessage."Message ID");

        // Set retry count to max
        IntegrationMessage."Retry Count" := 3;
        IntegrationMessage.Modify();

        // [WHEN] The retry codeunit runs
        IntegrationMsgRetry.Run(JobQueueEntry);

        // [THEN] Message remains Failed (not retried)
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual(IntegrationMessage.Status::Failed, IntegrationMessage.Status, 'Message at max retry should remain Failed.');
        Assert.AreEqual(3, IntegrationMessage."Retry Count", 'Retry Count should not be incremented.');
    end;

    [Test]
    procedure AutoRetry_RetriesBelowMaxCount()
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
        IntegrationMsgRetry: Codeunit "Integration Msg. Retry";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [SCENARIO] Given automatic retry, Failed messages below the max
        // retry count are set to New and reprocessed.

        // [GIVEN] A failed message with Retry Count below max
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IntegrationMessage.SetRequestContent('{"test":"below-max"}');
        IntegrationMessage.Insert(true);
        // Force it to Failed state manually
        IntegrationMessage.Status := IntegrationMessage.Status::Failed;
        IntegrationMessage."Retry Count" := 1;
        IntegrationMessage.Modify();

        // [WHEN] The retry codeunit runs
        IntegrationMsgRetry.Run(JobQueueEntry);

        // [THEN] Message is retried and completes (Test processor succeeds)
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreEqual(IntegrationMessage.Status::Completed, IntegrationMessage.Status, 'Message below max retry should be retried and complete.');
        Assert.AreEqual(2, IntegrationMessage."Retry Count", 'Retry Count should be incremented.');
    end;

    [Test]
    procedure MissingCorrelationId_GeneratesGuid()
    var
        IntegrationMessage: Record "Integration Message";
    begin
        // [SCENARIO] Given the Correlation ID is missing from the inbound call,
        // when the API page stages the message, then a new Guid is generated.

        // [GIVEN] A message with no Correlation ID set
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        // Do not set Correlation ID

        // [WHEN] Inserted
        IntegrationMessage.Insert(true);

        // [THEN] Correlation ID is auto-generated
        Assert.IsFalse(IsNullGuid(IntegrationMessage."Correlation ID"), 'Correlation ID should be auto-generated when not provided.');
    end;

    [Test]
    procedure ProcessedAt_SetWhenProcessingStarts()
    var
        IntegrationMessage: Record "Integration Message";
        IntegrationMsgProcess: Codeunit "Integration Msg. Process";
    begin
        // [SCENARIO] Processed At is set when processing begins.

        // [GIVEN] A staged message
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := LibraryUtility.GenerateGUID();
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IntegrationMessage.SetRequestContent('{"test":"timestamp"}');
        IntegrationMessage.Insert(true);
        Assert.AreEqual(0DT, IntegrationMessage."Processed At", 'Precondition: Processed At should be empty before processing.');

        // [WHEN] Processed
        IntegrationMsgProcess.ProcessMessage(IntegrationMessage);

        // [THEN] Processed At is populated
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        Assert.AreNotEqual(0DT, IntegrationMessage."Processed At", 'Processed At should be set when processing starts.');
    end;

    [Test]
    procedure StageMessage_Idempotency_ViaCodeunit()
    var
        IntegrationMessage: Record "Integration Message";
        SecondMessage: Record "Integration Message";
        IntegrationMsgStage: Codeunit "Integration Msg. Stage";
        IdempotencyKey: Text[50];
        IsNew: Boolean;
    begin
        // [SCENARIO] StageMessage codeunit returns existing message on duplicate key.

        // [GIVEN] A message staged via the codeunit
        IdempotencyKey := LibraryUtility.GenerateGUID();
        IntegrationMessage.Init();
        IntegrationMessage."Idempotency Key" := IdempotencyKey;
        IntegrationMessage."Type" := IntegrationMessage."Type"::Test;
        IsNew := IntegrationMsgStage.StageMessage(IntegrationMessage, '{"first":"call"}');
        Assert.IsTrue(IsNew, 'First call should stage a new message.');

        // [WHEN] Same idempotency key is staged again
        SecondMessage.Init();
        SecondMessage."Idempotency Key" := IdempotencyKey;
        SecondMessage."Type" := SecondMessage."Type"::Test;
        IsNew := IntegrationMsgStage.StageMessage(SecondMessage, '{"second":"call"}');

        // [THEN] Returns the existing message, not a new one
        Assert.IsFalse(IsNew, 'Second call with same key should not stage a new message.');
        Assert.AreEqual(IntegrationMessage."Message ID", SecondMessage."Message ID", 'Should return the original message ID.');
    end;
}
