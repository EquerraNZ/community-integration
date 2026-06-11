page 73298443 "Integration Message List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Integration Message";
    Caption = 'Integration Messages';
    CardPageId = "Integration Message Card";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    SourceTableView = sorting("Created At") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Messages)
            {
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lifecycle status of the message.';
                    StyleExpr = StatusStyle;
                }
                field("Type Code"; Rec."Type Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the integration message type.';
                }
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the message is inbound or outbound.';
                }
                field("External Reference"; Rec."External Reference")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source system reference that drives idempotency.';
                }
                field("Correlation ID"; Rec."Correlation ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the trace id shared across every hop of the flow.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central document the message produced.';
                }
                field("Error Class"; Rec."Error Class")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the last failure was classified.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many times the message has been retried.';
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the message was staged.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Resolve)
            {
                ApplicationArea = All;
                Caption = 'Resolve';
                Image = Approve;
                ToolTip = 'Re-queue the corrected message for the dispatcher, keeping the same message id.';
                Enabled = IsFailed;

                trigger OnAction()
                begin
                    ResolutionMgt.Resolve(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ConfirmByException)
            {
                ApplicationArea = All;
                Caption = 'Confirm by Exception';
                Image = Confirm;
                ToolTip = 'Accept the message as handled with no retry, keeping the audit record.';
                Enabled = IsFailed;

                trigger OnAction()
                begin
                    ResolutionMgt.ConfirmByException(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Reassign)
            {
                ApplicationArea = All;
                Caption = 'Reassign';
                Image = ChangeStatus;
                ToolTip = 'Re-resolve the handler from the corrected type code and re-queue the message.';
                Enabled = IsFailed;

                trigger OnAction()
                begin
                    ResolutionMgt.Reassign(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Resolve';

                actionref(Resolve_Promoted; Resolve) { }
                actionref(ConfirmByException_Promoted; ConfirmByException) { }
                actionref(Reassign_Promoted; Reassign) { }
            }
        }
    }

    var
        ResolutionMgt: Codeunit "Integration Resolution Mgt.";
        IsFailed: Boolean;
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        IsFailed := Rec.Status = Rec.Status::Failed;
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
