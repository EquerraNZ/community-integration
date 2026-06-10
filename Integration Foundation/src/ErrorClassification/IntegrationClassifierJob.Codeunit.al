// The out-of-band classification pass. Scheduled as its own Job Queue entry,
// separate from dispatch, so classification never slows the failure path and can be
// rerun or replaced independently. It finds failed, unclassified messages and asks
// the active classifier (resolved from setup) what class each failure is. Resolving
// the classifier from the "Error Classifier Type" enum is what makes it swappable:
// this job never names a concrete classifier codeunit.
codeunit 73298415 "Integration Classifier Job"
{
    Access = Public;

    trigger OnRun()
    begin
        ClassifyFailures();
    end;

    var
        Telemetry: Codeunit "Integration Telemetry";
        MessageMgt: Codeunit "Integration Message Mgt.";
        ClassifiedAsTxt: Label 'Classified as %1.', Comment = '%1 = the error class assigned';

    procedure ClassifyFailures()
    var
        IntegrationMessage: Record "Integration Message";
        Classifier: Interface IErrorClassifier;
        MessageIds: List of [Guid];
        MessageId: Guid;
    begin
        Classifier := GetActiveClassifier();

        IntegrationMessage.SetCurrentKey(Classified, Status);
        IntegrationMessage.SetRange(Classified, false);
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::Failed);
        IntegrationMessage.SetLoadFields("Message ID");
        if IntegrationMessage.FindSet() then
            repeat
                MessageIds.Add(IntegrationMessage."Message ID");
            until IntegrationMessage.Next() = 0;

        foreach MessageId in MessageIds do
            ClassifyOne(MessageId, Classifier);
    end;

    local procedure ClassifyOne(MessageId: Guid; Classifier: Interface IErrorClassifier)
    var
        IntegrationMessage: Record "Integration Message";
    begin
        // Take an update lock and re-check, the same claim discipline the dispatcher
        // and pipeline engine use, so two overlapping classifier runs cannot both
        // classify the same message (which would double the Classified log entry).
        IntegrationMessage.LockTable();
        if not IntegrationMessage.Get(MessageId) then
            exit;
        // A manual retry may have moved it off Failed between the scan and now.
        if (IntegrationMessage.Status <> IntegrationMessage.Status::Failed) or IntegrationMessage.Classified then
            exit;

        IntegrationMessage."Error Class" := Classifier.Classify(IntegrationMessage);
        IntegrationMessage.Classified := true;
        IntegrationMessage.Modify(true);
        MessageMgt.AppendLog(IntegrationMessage, "Integration Log Event"::Classified, StrSubstNo(ClassifiedAsTxt, Format(IntegrationMessage."Error Class")));
        Commit();
        Telemetry.LogClassified(IntegrationMessage);
    end;

    local procedure GetActiveClassifier(): Interface IErrorClassifier
    var
        IntegrationSetup: Record "Integration Setup";
    begin
        // Default to the rule-based classifier when setup has not been seeded yet,
        // so the job is safe to run on a brand-new install.
        if not IntegrationSetup.Get() then
            exit("Error Classifier Type"::Default);
        exit(IntegrationSetup."Active Error Classifier");
    end;
}
