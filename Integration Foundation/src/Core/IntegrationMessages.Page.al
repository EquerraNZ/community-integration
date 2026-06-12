page 73298401 "Integration Messages"
{
    ApplicationArea = All;
    Caption = 'Integration Messages';
    PageType = List;
    SourceTable = "Integration Message";
    UsageCategory = Lists;
    Editable = false;
    CardPageId = "Integration Message Card";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Message ID"; Rec."Message ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique identifier of the integration message.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document number of the integration message.';
                }
                field("Type"; Rec."Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the type of the integration message.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current processing status of the message.';
                    StyleExpr = StatusStyle;
                }
                field("Idempotency Key"; Rec."Idempotency Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the idempotency key used to prevent duplicate processing.';
                }
                field("Correlation ID"; Rec."Correlation ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the correlation identifier for tracing across systems.';
                }
                field("Error Code"; Rec."Error Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the error code if the message processing failed.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many times this message has been retried.';
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the message was received.';
                }
                field("Processed At"; Rec."Processed At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the message processing started.';
                }
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
                ToolTip = 'Retry processing the selected failed message.';
                Image = Refresh;
                Enabled = Rec.Status = Rec.Status::Failed;

                trigger OnAction()
                var
                    IntegrationMsgRetry: Codeunit "Integration Msg. Retry";
                begin
                    IntegrationMsgRetry.RetryManual(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Retry_Promoted; Retry)
                {
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Completed:
                StatusStyle := 'Favorable';
            Rec.Status::Failed:
                StatusStyle := 'Unfavorable';
            Rec.Status::"In Progress":
                StatusStyle := 'Ambiguous';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
