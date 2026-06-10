// The delayed-reply pattern. Some external systems answer later, not in the same
// call: you accept the request now (return 202 Accepted with a status URL) and the
// answer arrives minutes or hours later. The request is parked Awaiting Reply, and
// when the reply turns up it is matched back to the original by Correlation ID.
// Request and reply are two separate Integration Message rows that share one
// Correlation ID; the reply also points at the request through Parent Message ID,
// so the whole exchange is one traceable tree.
//
// The framework does the parking and the matching; it does not itself poll or call
// the external system. A consuming app's handler decides what the reply means and
// calls CompleteAwaitingRequest (or ResumeForProcessing) when it arrives.
codeunit 73298417 "Integration Reply Mgt."
{
    Access = Public;

    var
        Telemetry: Codeunit "Integration Telemetry";
        MessageMgt: Codeunit "Integration Message Mgt.";
        NoParkedRequestErr: Label 'No request is awaiting a reply for correlation id %1.', Comment = '%1 = correlation id';
        ParkedTxt: Label 'Parked awaiting reply.', Comment = 'Audit log entry written when a request is parked to await a later reply.';
        ReplyMatchedTxt: Label 'Reply %1 matched to this request.', Comment = '%1 = reply message id';

    /// <summary>
    /// Park a request to await a later reply. Typically called from inside a
    /// handler that has accepted the work and received a status URL. The dispatcher
    /// sees the message is no longer In Progress and leaves it parked.
    /// </summary>
    procedure ParkAwaitingReply(var IntegrationMessage: Record "Integration Message"; StatusUrl: Text)
    begin
        IntegrationMessage.Get(IntegrationMessage."Message ID");
        IntegrationMessage.Status := IntegrationMessage.Status::"Awaiting Reply";
        IntegrationMessage."Status URL" := CopyStr(StatusUrl, 1, MaxStrLen(IntegrationMessage."Status URL"));
        IntegrationMessage.Modify(true);
        MessageMgt.AppendLog(IntegrationMessage, "Integration Log Event"::Parked, ParkedTxt);
        Telemetry.LogParked(IntegrationMessage);
    end;

    /// <summary>
    /// Find the request that is awaiting a reply for a correlation id. Returns false
    /// when none is parked (the reply may have arrived first, or be a duplicate).
    /// </summary>
    procedure TryFindParkedRequest(CorrelationId: Code[40]; var RequestMessage: Record "Integration Message"): Boolean
    begin
        RequestMessage.Reset();
        RequestMessage.SetCurrentKey("Correlation ID");
        RequestMessage.SetRange("Correlation ID", CorrelationId);
        RequestMessage.SetRange(Status, RequestMessage.Status::"Awaiting Reply");
        exit(RequestMessage.FindFirst());
    end;

    /// <summary>
    /// Match an arriving reply to its parked request and resolve the request with
    /// the reply payload. Links the reply to the request (Parent Message ID) so the
    /// two rows, already sharing a Correlation ID, form one traceable exchange.
    /// </summary>
    procedure CompleteAwaitingRequest(var ReplyMessage: Record "Integration Message"; ReplyPayload: Text)
    var
        RequestMessage: Record "Integration Message";
    begin
        if not TryFindParkedRequest(ReplyMessage."Correlation ID", RequestMessage) then
            Error(NoParkedRequestErr, ReplyMessage."Correlation ID");

        LinkReplyToRequest(ReplyMessage, RequestMessage);

        MessageMgt.SetResponseText(RequestMessage, ReplyPayload);
        MessageMgt.MarkResolved(RequestMessage);
        MessageMgt.AppendLog(RequestMessage, "Integration Log Event"::"Reply Matched", StrSubstNo(ReplyMatchedTxt, Format(ReplyMessage."Message ID", 0, 4)));
        Commit();
        Telemetry.LogReplyMatched(RequestMessage);
    end;

    /// <summary>
    /// Alternative to CompleteAwaitingRequest when the reply needs the request's own
    /// handler to run again (rather than just being resolved): match, link, and put
    /// the request back to New so the dispatcher re-runs its handler with the reply
    /// payload now available. The same Message ID and idempotency key are reused.
    /// </summary>
    procedure ResumeForProcessing(var ReplyMessage: Record "Integration Message"; ReplyPayload: Text)
    var
        RequestMessage: Record "Integration Message";
    begin
        if not TryFindParkedRequest(ReplyMessage."Correlation ID", RequestMessage) then
            Error(NoParkedRequestErr, ReplyMessage."Correlation ID");

        LinkReplyToRequest(ReplyMessage, RequestMessage);

        MessageMgt.SetResponseText(RequestMessage, ReplyPayload);
        RequestMessage.Status := RequestMessage.Status::New;
        RequestMessage.Modify(true);
        MessageMgt.AppendLog(RequestMessage, "Integration Log Event"::"Reply Matched", StrSubstNo(ReplyMatchedTxt, Format(ReplyMessage."Message ID", 0, 4)));
        Commit();
        Telemetry.LogReplyMatched(RequestMessage);
    end;

    local procedure LinkReplyToRequest(var ReplyMessage: Record "Integration Message"; var RequestMessage: Record "Integration Message")
    begin
        ReplyMessage.Get(ReplyMessage."Message ID");
        ReplyMessage."Parent Message ID" := RequestMessage."Message ID";
        if ReplyMessage."Correlation ID" = '' then
            ReplyMessage."Correlation ID" := RequestMessage."Correlation ID";
        ReplyMessage.Modify(true);
    end;
}
