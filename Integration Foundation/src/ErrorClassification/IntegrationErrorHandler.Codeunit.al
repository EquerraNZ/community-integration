// Durable error capture. When a handler or a stage fails, the dispatcher calls
// this with the error text it read from GetLastErrorText. Because the handler ran
// inside a Codeunit.Run boundary, its own work has already rolled back, but the
// committed In Progress row has not, so we can write a durable Failed record here
// and commit it. Classification is deliberately NOT done here: capture is fast and
// in the failure path, classification is a separate out-of-band pass. That keeps
// the failure path small and lets the classifier be swapped without touching this
// code.
codeunit 73298414 "Integration Error Handler"
{
    Access = Public;

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        Telemetry: Codeunit "Integration Telemetry";

    /// <summary>
    /// Record a failure durably on the message: store the error text, flip to
    /// Failed, stamp the time, bump the retry count, and mark it unclassified so
    /// the classifier job will pick it up. Does not classify inline.
    /// </summary>
    procedure Capture(var IntegrationMessage: Record "Integration Message"; ErrorText: Text)
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        IntegrationMessage.Status := IntegrationMessage.Status::Failed;
        IntegrationMessage."Failed At" := CurrentDateTime();
        IntegrationMessage."Retry Count" += 1;
        IntegrationMessage."Error Class" := IntegrationMessage."Error Class"::Unknown;
        IntegrationMessage.Classified := false;
        IntegrationMessage.Modify(true);
        MessageMgt.SetErrorText(IntegrationMessage, ErrorText);
        MessageMgt.AppendLog(IntegrationMessage, "Integration Log Event"::Failed, CopyStr(ErrorText, 1, 250));
        Commit();
        Telemetry.LogFailed(IntegrationMessage);
    end;
}
