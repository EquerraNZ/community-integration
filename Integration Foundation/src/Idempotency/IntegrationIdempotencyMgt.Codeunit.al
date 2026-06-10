// Duplicate detection. The stable external reference from the source system, paired
// with the type, is the idempotency key. Duplicates are a guarantee, not an edge
// case: a source system re-fetches on restart, a webhook fires twice, a caller
// retries on a timeout that actually succeeded. The rule is that a repeated request
// keyed on the same (External Reference, Type) never causes a second side effect,
// and the caller cannot tell a retry from the first attempt because it receives the
// original stored response.
//
// The internal Message ID is never the dedup key: it is unique per row by design.
// Only the external reference is stable across retries.
codeunit 73298413 "Integration Idempotency Mgt."
{
    Access = Public;

    /// <summary>
    /// Look up a prior message with the same external reference and type. Messages
    /// with no external reference (typically outbound, or items the source cannot
    /// key) are never deduplicated, so a blank reference returns false.
    /// </summary>
    procedure TryGetExisting(IntegrationType: Enum "Integration Type"; ExternalReference: Text; var ExistingMessage: Record "Integration Message"): Boolean
    begin
        if ExternalReference = '' then
            exit(false);

        ExistingMessage.Reset();
        ExistingMessage.SetCurrentKey("External Reference", Type);
        ExistingMessage.SetRange("External Reference", CopyStr(ExternalReference, 1, MaxStrLen(ExistingMessage."External Reference")));
        ExistingMessage.SetRange(Type, IntegrationType);
        exit(ExistingMessage.FindFirst());
    end;

    /// <summary>
    /// True when a prior message for this key has already been resolved. The caller
    /// should replay that message's stored response rather than process again.
    /// </summary>
    procedure IsResolvedDuplicate(IntegrationType: Enum "Integration Type"; ExternalReference: Text; var ExistingMessage: Record "Integration Message"): Boolean
    begin
        if not TryGetExisting(IntegrationType, ExternalReference, ExistingMessage) then
            exit(false);
        exit(ExistingMessage.Status = ExistingMessage.Status::Resolved);
    end;

    /// <summary>
    /// True when a prior message for this key is still being worked (New,
    /// In Progress, or Awaiting Reply). A duplicate arriving now must not start a
    /// second handler run; the caller should return the in-flight message.
    /// </summary>
    procedure IsInFlightDuplicate(IntegrationType: Enum "Integration Type"; ExternalReference: Text; var ExistingMessage: Record "Integration Message"): Boolean
    begin
        if not TryGetExisting(IntegrationType, ExternalReference, ExistingMessage) then
            exit(false);
        exit(ExistingMessage.Status in [ExistingMessage.Status::New, ExistingMessage.Status::"In Progress", ExistingMessage.Status::"Awaiting Reply"]);
    end;

    /// <summary>
    /// Find an already-resolved message with the same key, other than the one being
    /// processed. The dispatcher uses this as a safety net: if a duplicate New row
    /// reached it by any path (a direct API insert, say), it replays the resolved
    /// twin's response instead of running the handler a second time. This is what
    /// makes the no-second-side-effect guarantee hold regardless of entry path.
    /// </summary>
    procedure TryGetResolvedTwin(IntegrationType: Enum "Integration Type"; ExternalReference: Text; ExcludeMessageId: Guid; var ExistingMessage: Record "Integration Message"): Boolean
    begin
        if ExternalReference = '' then
            exit(false);

        ExistingMessage.Reset();
        ExistingMessage.SetCurrentKey("External Reference", Type);
        ExistingMessage.SetRange("External Reference", CopyStr(ExternalReference, 1, MaxStrLen(ExistingMessage."External Reference")));
        ExistingMessage.SetRange(Type, IntegrationType);
        ExistingMessage.SetRange(Status, ExistingMessage.Status::Resolved);
        ExistingMessage.SetFilter("Message ID", '<>%1', ExcludeMessageId);
        exit(ExistingMessage.FindFirst());
    end;
}
