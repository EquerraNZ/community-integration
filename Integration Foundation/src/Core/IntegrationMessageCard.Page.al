page 73298402 "Integration Message Card"
{
    ApplicationArea = All;
    Caption = 'Integration Message Card';
    PageType = Card;
    SourceTable = "Integration Message";
    Editable = false;

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
                field("Parent Message ID"; Rec."Parent Message ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the parent message for staged pipeline tracing.';
                }
            }
            group(Processing)
            {
                Caption = 'Processing';

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
            group(RequestContentGroup)
            {
                Caption = 'Request Content';

                field(RequestContent; RequestContentText)
                {
                    ApplicationArea = All;
                    Caption = 'Request Content';
                    ToolTip = 'Specifies the inbound payload content.';
                    MultiLine = true;
                }
            }
            group(ResponseContentGroup)
            {
                Caption = 'Response Content';

                field(ResponseContent; ResponseContentText)
                {
                    ApplicationArea = All;
                    Caption = 'Response Content';
                    ToolTip = 'Specifies the response content after processing.';
                    MultiLine = true;
                }
            }
            group(ErrorContentGroup)
            {
                Caption = 'Error Content';

                field(ErrorContent; ErrorContentText)
                {
                    ApplicationArea = All;
                    Caption = 'Error Content';
                    ToolTip = 'Specifies the error details if processing failed.';
                    MultiLine = true;
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
                ToolTip = 'Retry processing this failed message.';
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
        RequestContentText := Rec.GetRequestContent();
        ResponseContentText := Rec.GetResponseContent();
        ErrorContentText := Rec.GetErrorContent();

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
        RequestContentText: Text;
        ResponseContentText: Text;
        ErrorContentText: Text;
        StatusStyle: Text;
}
