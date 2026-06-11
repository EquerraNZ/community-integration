table 73298400 "Integration Message"
{
    Caption = 'Integration Message';
    DataClassification = CustomerContent;
    LookupPageId = "Integration Message List";
    DrillDownPageId = "Integration Message List";

    fields
    {
        field(1; "Message ID"; Guid)
        {
            Caption = 'Message ID';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(2; Direction; Enum "Integration Direction")
        {
            Caption = 'Direction';
            DataClassification = SystemMetadata;
        }
        field(3; "Type"; Enum "Integration Message Type")
        {
            Caption = 'Type';
            DataClassification = SystemMetadata;
        }
        field(4; "Type Code"; Code[40])
        {
            Caption = 'Type Code';
            DataClassification = SystemMetadata;
        }
        field(5; Status; Enum "Integration Msg. Status")
        {
            Caption = 'Status';
            DataClassification = SystemMetadata;
        }
        field(6; "External Reference"; Text[100])
        {
            Caption = 'External Reference';
            DataClassification = SystemMetadata;
        }
        field(7; "Correlation ID"; Code[40])
        {
            Caption = 'Correlation ID';
            DataClassification = SystemMetadata;
        }
        field(8; "Parent Message ID"; Guid)
        {
            Caption = 'Parent Message ID';
            DataClassification = SystemMetadata;
        }
        field(9; "Document No."; Code[40])
        {
            Caption = 'Document No.';
            DataClassification = SystemMetadata;
        }
        field(10; Request; Blob)
        {
            Caption = 'Request';
            DataClassification = CustomerContent;
        }
        field(11; Response; Blob)
        {
            Caption = 'Response';
            DataClassification = CustomerContent;
        }
        field(12; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            DataClassification = CustomerContent;
        }
        field(13; "Error Class"; Enum "Integration Error Class")
        {
            Caption = 'Error Class';
            DataClassification = SystemMetadata;
        }
        field(14; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 0;
        }
        field(15; "Created At"; DateTime)
        {
            Caption = 'Created At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(16; "Created By User"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(17; "Last Modified At"; DateTime)
        {
            Caption = 'Last Modified At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(18; "Last Modified By User"; Code[50])
        {
            Caption = 'Last Modified By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Message ID") { Clustered = true; }
        // Idempotency: a replayed delivery is detected on the source's stable id, and a
        // racing duplicate insert fails at the database rather than creating a second row.
        key(Idempotency; "External Reference", "Type") { Unique = true; }
        // The only key the dispatcher filters on: New inbound rows oldest first.
        key(Dispatch; Status, Direction, "Created At") { }
    }

    /// <summary>Write a payload string into the Request blob (UTF8).</summary>
    procedure SetRequest(Payload: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Request);
        Request.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Payload);
    end;

    /// <summary>Read the Request blob back as a string.</summary>
    procedure GetRequest(): Text
    var
        InStr: InStream;
    begin
        CalcFields(Request);
        if not Request.HasValue() then
            exit('');
        Request.CreateInStream(InStr, TextEncoding::UTF8);
        exit(ReadStreamAsText(InStr));
    end;

    /// <summary>Write a payload string into the Response blob (UTF8).</summary>
    procedure SetResponse(Payload: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Response);
        Response.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Payload);
    end;

    /// <summary>Read the Response blob back as a string.</summary>
    procedure GetResponse(): Text
    var
        InStr: InStream;
    begin
        CalcFields(Response);
        if not Response.HasValue() then
            exit('');
        Response.CreateInStream(InStr, TextEncoding::UTF8);
        exit(ReadStreamAsText(InStr));
    end;

    local procedure ReadStreamAsText(var InStr: InStream): Text
    var
        Line: Text;
        Content: TextBuilder;
    begin
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            Content.Append(Line);
        end;
        exit(Content.ToText());
    end;
}
