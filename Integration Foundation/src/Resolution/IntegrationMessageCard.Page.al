page 73298444 "Integration Message Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "Integration Message";
    Caption = 'Integration Message';
    InsertAllowed = false;
    DeleteAllowed = false;

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
                    Editable = false;
                    ToolTip = 'Specifies the internal message id, reused across every retry so idempotency holds.';
                }
                field("Type Code"; Rec."Type Code")
                {
                    ApplicationArea = All;
                    Editable = IsFailed;
                    ToolTip = 'Specifies the integration message type. Editable while Failed so a misrouted message can be reassigned.';
                }
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies whether the message is inbound or outbound.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the lifecycle status of the message.';
                }
                field("External Reference"; Rec."External Reference")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the source system reference that drives idempotency.';
                }
                field("Correlation ID"; Rec."Correlation ID")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the trace id shared across every hop of the flow.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the Business Central document the message produced.';
                }
            }
            group(ErrorInfo)
            {
                Caption = 'Error';

                field("Error Class"; Rec."Error Class")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies how the last failure was classified.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Specifies the last error recorded against the message.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies how many times the message has been retried.';
                }
            }
            group(Payloads)
            {
                Caption = 'Payload';

                field(RequestPayload; RequestPayloadText)
                {
                    ApplicationArea = All;
                    Caption = 'Request';
                    MultiLine = true;
                    Editable = IsFailed;
                    ToolTip = 'Specifies the request payload. Editable while Failed so a data error can be corrected before re-running.';

                    trigger OnValidate()
                    begin
                        Rec.SetRequest(RequestPayloadText);
                        Rec.Modify(true);
                    end;
                }
                field(ResponsePayload; ResponsePayloadText)
                {
                    ApplicationArea = All;
                    Caption = 'Response';
                    MultiLine = true;
                    Editable = false;
                    ToolTip = 'Specifies the response payload recorded for the message.';
                }
            }
            group(Audit)
            {
                Caption = 'Audit';

                field("Created At"; Rec."Created At") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies when the message was staged.'; }
                field("Created By User"; Rec."Created By User") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies who staged the message.'; }
                field("Last Modified At"; Rec."Last Modified At") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies when the message was last changed.'; }
                field("Last Modified By User"; Rec."Last Modified By User") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies who last changed the message.'; }
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
        RequestPayloadText: Text;
        ResponsePayloadText: Text;
        IsFailed: Boolean;

    trigger OnAfterGetRecord()
    begin
        IsFailed := Rec.Status = Rec.Status::Failed;
        RequestPayloadText := Rec.GetRequest();
        ResponsePayloadText := Rec.GetResponse();
    end;
}
