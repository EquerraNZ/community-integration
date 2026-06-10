// The operations list: the home for monitoring and recovering integration work. It
// is the single place to see every message across every pattern, filter to the
// stuck ones, and act. Modelled on the standard inbound staging experience. No
// FlowField columns here on purpose; the counts live in the Activities factbox so
// the list stays fast on a tenant with a large backlog.
page 73298450 "Integration Messages"
{
    PageType = List;
    SourceTable = "Integration Message";
    Caption = 'Integration Messages';
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "Integration Message Card";
    Editable = false;
    SourceTableView = sorting(Status, Direction, SystemCreatedAt) order(descending);

    layout
    {
        area(Content)
        {
            repeater(Messages)
            {
                field(Type; Rec.Type)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the integration type, which determines the handler that processes the message.';
                }
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the message is inbound or outbound.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies where the message is in its lifecycle.';
                    StyleExpr = StatusStyle;
                }
                field("External Reference"; Rec."External Reference")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the stable identifier from the source system, used to detect duplicates.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central document the message relates to, if any.';
                }
                field("Current Stage"; Rec."Current Stage")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the pipeline stage the message is at. Blank for single-handler messages.';
                }
                field("Error Class"; Rec."Error Class")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how a failure was classified, once the classifier has run.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many times processing has been attempted.';
                }
                field("Assigned To User ID"; Rec."Assigned To User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who owns this message for recovery.';
                }
                field("Correlation ID"; Rec."Correlation ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the trace id shared across the whole flow, including request and reply.';
                    Visible = false;
                }
                field(SystemCreatedAt; Rec.SystemCreatedAt)
                {
                    ApplicationArea = All;
                    Caption = 'Created At';
                    ToolTip = 'Specifies when the message was staged.';
                }
            }
        }
        area(FactBoxes)
        {
            part(Activities; "Integration Activities")
            {
                ApplicationArea = All;
            }
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
        }
        area(Navigation)
        {
            action(OpenCard)
            {
                ApplicationArea = All;
                Caption = 'Inspect';
                ToolTip = 'Open the message to inspect its payloads, error, and activity log, and to resolve by exception or reassign it.';
                Image = ViewDetails;
                RunObject = page "Integration Message Card";
                RunPageOnRec = true;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Retry_Promoted; Retry) { }
                actionref(Resolve_Promoted; Resolve) { }
                actionref(OpenCard_Promoted; OpenCard) { }
            }
        }
    }

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        StatusStyle := StatusStyleExpr();
    end;

    local procedure StatusStyleExpr(): Text
    begin
        case Rec.Status of
            Rec.Status::Failed:
                exit('Unfavorable');
            Rec.Status::Resolved:
                exit('Favorable');
            Rec.Status::"Awaiting Reply":
                exit('Ambiguous');
            else
                exit('Standard');
        end;
    end;
}
