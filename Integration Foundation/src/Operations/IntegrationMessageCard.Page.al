// The message card: inspect one message in full and run every recovery action. The
// payloads and the error text are blobs, so they are surfaced through read-only
// text variables populated when the record loads. This is where an operator fixes a
// stuck message: read the error, retry, resolve, resolve by exception with a reason,
// or reassign to someone else. Every action keeps the audit trail.
page 73298451 "Integration Message Card"
{
    PageType = Card;
    SourceTable = "Integration Message";
    Caption = 'Integration Message';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Message ID"; Rec."Message ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique id of this message. It is never reused and never the duplicate-detection key.';
                    Editable = false;
                }
                field(Type; Rec.Type)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the integration type, which determines the handler that processes the message.';
                    Editable = false;
                }
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the message is inbound or outbound.';
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies where the message is in its lifecycle.';
                    Editable = false;
                }
                field("External Reference"; Rec."External Reference")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the stable identifier from the source system, used to detect duplicates.';
                    Editable = false;
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central document the message relates to, if any.';
                    Editable = false;
                }
                field("Source System"; Rec."Source System")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies where the message originated.';
                    Editable = false;
                }
                field("Correlation ID"; Rec."Correlation ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the trace id shared across the whole flow, including the request and any reply.';
                    Editable = false;
                }
                field("Parent Message ID"; Rec."Parent Message ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the message this one was spawned from, or the request a reply was matched to.';
                    Editable = false;
                }
            }
            group(Pipeline)
            {
                Caption = 'Pipeline';

                field("Current Stage"; Rec."Current Stage")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the pipeline stage to run next. Blank for single-handler messages.';
                    Editable = false;
                }
            }
            group(ErrorAndRetry)
            {
                Caption = 'Error and Retry';

                field("Error Class"; Rec."Error Class")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the failure was classified, once the classifier has run.';
                    Editable = false;
                }
                field(Classified; Rec.Classified)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the classifier has assigned an error class yet.';
                    Editable = false;
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many times processing has been attempted.';
                    Editable = false;
                }
                field(ErrorMessageText; ErrorMessageText)
                {
                    ApplicationArea = All;
                    Caption = 'Error Message';
                    ToolTip = 'Specifies the last error captured for this message.';
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(Payloads)
            {
                Caption = 'Payloads';

                field(RequestText; RequestText)
                {
                    ApplicationArea = All;
                    Caption = 'Request';
                    ToolTip = 'Specifies the request payload as received.';
                    Editable = false;
                    MultiLine = true;
                }
                field(ResponseText; ResponseText)
                {
                    ApplicationArea = All;
                    Caption = 'Response';
                    ToolTip = 'Specifies the response payload. This is what a duplicate caller is replayed.';
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(Recovery)
            {
                Caption = 'Recovery';

                field(ResolutionReason; ResolutionReason)
                {
                    ApplicationArea = All;
                    Caption = 'Resolution Reason';
                    ToolTip = 'Specifies the reason to record when resolving this message by exception.';
                    MultiLine = true;
                }
            }
            group(Timing)
            {
                Caption = 'Timing';

                field("Processed At"; Rec."Processed At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when processing last started.';
                    Editable = false;
                }
                field("Failed At"; Rec."Failed At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the message last failed.';
                    Editable = false;
                }
                field("Resolved At"; Rec."Resolved At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the message was resolved.';
                    Editable = false;
                }
                field("Status URL"; Rec."Status URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the URL to poll for a long-running reply.';
                    Editable = false;
                }
                field("Assigned To User ID"; Rec."Assigned To User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who owns this message for recovery. Use the Reassign action to change and record it.';
                    Editable = false;
                }
            }
        }
        area(FactBoxes)
        {
            part(ActivityLog; "Integration Message Log Part")
            {
                ApplicationArea = All;
                SubPageLink = "Message ID" = field("Message ID");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Retry)
            {
                ApplicationArea = All;
                Caption = 'Retry';
                ToolTip = 'Send the failed message back for reprocessing. The same Message ID and idempotency key are reused, so no second side effect can occur.';
                Image = Restore;

                trigger OnAction()
                begin
                    MessageMgt.Retry(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Resolve)
            {
                ApplicationArea = All;
                Caption = 'Resolve';
                ToolTip = 'Mark the message resolved without reprocessing.';
                Image = Approve;

                trigger OnAction()
                begin
                    MessageMgt.Resolve(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ResolveByException)
            {
                ApplicationArea = All;
                Caption = 'Resolve by Exception';
                ToolTip = 'Close the message without reprocessing and record the reason. Use when the work will never succeed as-is.';
                Image = ApproveReject;

                trigger OnAction()
                begin
                    if ResolutionReason = '' then
                        Error(ReasonRequiredErr);
                    MessageMgt.ResolveByException(Rec, ResolutionReason);
                    ResolutionReason := '';
                    CurrPage.Update(false);
                end;
            }
            action(Reassign)
            {
                ApplicationArea = All;
                Caption = 'Reassign';
                ToolTip = 'Hand this message to another user for triage or fixing. The status does not change.';
                Image = Job;

                trigger OnAction()
                var
                    User: Record User;
                begin
                    if Page.RunModal(Page::Users, User) <> Action::LookupOK then
                        exit;
                    MessageMgt.Reassign(Rec, CopyStr(User."User Name", 1, MaxStrLen(Rec."Assigned To User ID")));
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Retry_Promoted; Retry) { }
                actionref(Resolve_Promoted; Resolve) { }
                actionref(ResolveByException_Promoted; ResolveByException) { }
                actionref(Reassign_Promoted; Reassign) { }
            }
        }
    }

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        RequestText: Text;
        ResponseText: Text;
        ErrorMessageText: Text;
        ResolutionReason: Text;
        ReasonRequiredErr: Label 'Enter a resolution reason before resolving by exception.', Comment = 'Shown when the operator clicks Resolve by Exception without entering a reason.';

    trigger OnAfterGetRecord()
    begin
        RequestText := MessageMgt.GetRequestText(Rec);
        ResponseText := MessageMgt.GetResponseText(Rec);
        ErrorMessageText := MessageMgt.GetErrorText(Rec);
    end;
}
