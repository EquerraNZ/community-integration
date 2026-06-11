// Best practice: a resolution page over failed messages. Ops corrects the payload and flips
// Status to New; the processor re-runs the SAME Message ID under the SAME idempotency key, so
// the fix reprocesses without creating a duplicate. The shape mirrors what Microsoft ships for
// E-Document: editable staging, a resolution page, a status enum, retry actions, and an audit trail.

page 50220 "Integration Resolution"
{
    PageType = List;
    SourceTable = "Integration Message";
    // Failed messages stay EDITABLE so ops can correct the payload without a developer or a deploy.
    Editable = true;
    SourceTableView = where(Status = const(Failed));
    Caption = 'Integration Resolution';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                // The id is shown but NOT editable: re-running must reuse it so the idempotency
                // key stays the same and the retry cannot double-apply.
                field("Message ID"; Rec."Message ID") { Editable = false; }
                field("Idempotency Key"; Rec."Idempotency Key") { Editable = false; }
                field("Document No."; Rec."Document No.") { Editable = false; }
                // The error context ops needs to diagnose the failure. Read-only: it is history.
                field("Error Code"; Rec."Error Code") { Editable = false; }
                field("Error Content"; Rec.GetErrorContent()) { Editable = false; }
                // The payload ops actually edits to fix a malformed or mis-mapped message.
                field(RequestContent; Rec.GetRequestContent()) { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Resolve)
            {
                Caption = 'Resolve';
                trigger OnAction()
                begin
                    // Re-run the SAME message: same Message ID, therefore same idempotency key.
                    // The processor reprocesses the corrected payload, and the receiver recognises
                    // the repeat, so a side effect that partly landed is not applied a second time.
                    Rec.Status := Rec.Status::New;
                    Rec.Modify(true);
                end;
            }
            action(ConfirmByException)
            {
                Caption = 'Confirm by Exception';
                trigger OnAction()
                begin
                    // Accept as handled with NO retry (for example the work was completed manually
                    // out of band). The audit record is kept so the decision is traceable.
                    Rec.Status := Rec.Status::Completed;
                    Rec.Modify(true);
                end;
            }
        }
    }
}
