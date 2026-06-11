page 73298440 "Integration Message API"
{
    PageType = API;
    Caption = 'Integration Message';
    APIPublisher = 'equerra';
    APIGroup = 'integration';
    APIVersion = 'v1.0';
    EntityName = 'integrationMessage';
    EntitySetName = 'integrationMessages';
    SourceTable = "Integration Message";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    Extensible = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            field(id; Rec.SystemId)
            {
                Caption = 'Id';
                Editable = false;
            }
            field(messageId; Rec."Message ID")
            {
                Caption = 'Message Id';
                Editable = false;
            }
            field(messageType; Rec."Type Code")
            {
                Caption = 'Message Type';
            }
            field(externalReference; Rec."External Reference")
            {
                Caption = 'External Reference';
            }
            field(correlationId; Rec."Correlation ID")
            {
                Caption = 'Correlation Id';
            }
            field(direction; Rec.Direction)
            {
                Caption = 'Direction';
                Editable = false;
            }
            field(status; Rec.Status)
            {
                Caption = 'Status';
                Editable = false;
            }
            field(payload; PayloadJson)
            {
                Caption = 'Payload';
            }
            field(lastModifiedDateTime; Rec."Last Modified At")
            {
                Caption = 'Last Modified Date Time';
                Editable = false;
            }
        }
    }

    var
        MessageMgt: Codeunit "Integration Message Mgt.";
        PayloadJson: Text;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        StagedMessage: Record "Integration Message";
    begin
        // The whole staging decision (dedup, correlation, forced Direction/Status) is
        // delegated to the management seam, then Rec is set to the staged-or-existing
        // row so the API returns it. exit(false) tells the framework not to insert
        // again: the row already exists. Re-delivery returns the prior row, not a copy.
        StagedMessage.Get(MessageMgt.StageInbound(Rec."Type Code", Rec."External Reference", Rec."Correlation ID", PayloadJson));
        Rec := StagedMessage;
        exit(false);
    end;
}
