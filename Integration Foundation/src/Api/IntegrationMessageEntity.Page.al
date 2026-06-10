// The single inbound staging endpoint. One API page over the Integration Message,
// with the Type field routing each posted item to its handler: a consuming source
// system POSTs here with a type and an external reference, and the dispatcher does
// the rest. There is deliberately not a separate API page per source system.
//
// House rule: no ODataKeyFields. The SystemId is the API key.
//
// Idempotency holds on this path too: the dispatcher's resolved-twin check means a
// duplicate POST (same External Reference and Type) never causes a second side
// effect even though the POST itself inserts a row.
page 73298455 "Integration Message Entity"
{
    PageType = API;
    Caption = 'Integration Message';
    APIPublisher = 'equerra';
    APIGroup = 'integration';
    APIVersion = 'v1.0';
    EntityName = 'integrationMessage';
    EntitySetName = 'integrationMessages';
    SourceTable = "Integration Message";
    DelayedInsert = true;
    // No ODataKeyFields (house rule house:no-odatakeyfields). The stable Message ID
    // primary key is the OData key, which never changes for the life of the row.

    layout
    {
        area(Content)
        {
            repeater(Messages)
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
                field(type; Rec.Type)
                {
                    Caption = 'Type';
                }
                field(direction; Rec.Direction)
                {
                    Caption = 'Direction';
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                    Editable = false;
                }
                field(externalReference; Rec."External Reference")
                {
                    Caption = 'External Reference';
                }
                field(correlationId; Rec."Correlation ID")
                {
                    Caption = 'Correlation Id';
                }
                field(documentNo; Rec."Document No.")
                {
                    Caption = 'Document No.';
                }
                field(sourceSystem; Rec."Source System")
                {
                    Caption = 'Source System';
                }
                field(errorClass; Rec."Error Class")
                {
                    Caption = 'Error Class';
                    Editable = false;
                }
                field(retryCount; Rec."Retry Count")
                {
                    Caption = 'Retry Count';
                    Editable = false;
                }
                field(requestBody; Rec.Request)
                {
                    Caption = 'Request Body';
                }
                field(responseBody; Rec.Response)
                {
                    Caption = 'Response Body';
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified Date Time';
                    Editable = false;
                }
            }
        }
    }

    // No OnInsertRecord override is needed: a posted message defaults to Status New
    // and Direction Inbound (the zero values of those enums), and the table's
    // OnInsert trigger fills the Message ID and Correlation ID. The dispatcher's
    // resolved-twin check provides idempotency for this path.
}
