page 73298400 "Integration Messages API"
{
    APIGroup = 'integration';
    APIPublisher = 'equerra';
    APIVersion = 'v1.0';
    EntityName = 'integrationMessage';
    EntitySetName = 'integrationMessages';
    PageType = API;
    SourceTable = "Integration Message";
    Caption = 'Integration Messages API';
    DelayedInsert = true;
    Extensible = false;
    InsertAllowed = true;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(messageId; Rec."Message ID")
                {
                    Caption = 'Message ID';
                    Editable = false;
                }
                field(documentNo; Rec."Document No.")
                {
                    Caption = 'Document No.';
                    Editable = false;
                }
                field(type; Rec."Type")
                {
                    Caption = 'Type';
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                    Editable = false;
                }
                field(idempotencyKey; Rec."Idempotency Key")
                {
                    Caption = 'Idempotency Key';
                }
                field(correlationId; Rec."Correlation ID")
                {
                    Caption = 'Correlation ID';
                }
                field(parentMessageId; Rec."Parent Message ID")
                {
                    Caption = 'Parent Message ID';
                }
                field(errorCode; Rec."Error Code")
                {
                    Caption = 'Error Code';
                    Editable = false;
                }
                field(retryCount; Rec."Retry Count")
                {
                    Caption = 'Retry Count';
                    Editable = false;
                }
                field(createdAt; Rec."Created At")
                {
                    Caption = 'Created At';
                    Editable = false;
                }
                field(processedAt; Rec."Processed At")
                {
                    Caption = 'Processed At';
                    Editable = false;
                }
                field(requestContent; RequestContentText)
                {
                    Caption = 'Request Content';
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        IntegrationMsgStage: Codeunit "Integration Msg. Stage";
    begin
        IntegrationMsgStage.StageAndProcess(Rec, RequestContentText);
        exit(false);
    end;

    trigger OnAfterGetRecord()
    begin
        RequestContentText := Rec.GetRequestContent();
    end;

    var
        RequestContentText: Text;
}
