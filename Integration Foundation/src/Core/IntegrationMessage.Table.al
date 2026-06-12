table 73298400 "Integration Message"
{
    Caption = 'Integration Message';
    DataClassification = SystemMetadata;
    LookupPageId = "Integration Messages";
    DrillDownPageId = "Integration Messages";

    fields
    {
        field(1; "Message ID"; Guid)
        {
            Caption = 'Message ID';
            DataClassification = SystemMetadata;
        }
        field(2; "Document No."; Text[50])
        {
            Caption = 'Document No.';
            DataClassification = SystemMetadata;
        }
        field(3; "Type"; Enum "Integration Message Type")
        {
            Caption = 'Type';
            DataClassification = SystemMetadata;
        }
        field(4; Status; Enum "Integration Message Status")
        {
            Caption = 'Status';
            DataClassification = SystemMetadata;
        }
        field(5; "Idempotency Key"; Text[50])
        {
            Caption = 'Idempotency Key';
            DataClassification = SystemMetadata;
        }
        field(6; "Correlation ID"; Guid)
        {
            Caption = 'Correlation ID';
            DataClassification = SystemMetadata;
        }
        field(7; "Parent Message ID"; Guid)
        {
            Caption = 'Parent Message ID';
            DataClassification = SystemMetadata;
            TableRelation = "Integration Message"."Message ID";
        }
        field(8; "Request Content"; Blob)
        {
            Caption = 'Request Content';
            DataClassification = CustomerContent;
        }
        field(9; "Response Content"; Blob)
        {
            Caption = 'Response Content';
            DataClassification = CustomerContent;
        }
        field(10; "Error Content"; Blob)
        {
            Caption = 'Error Content';
            DataClassification = SystemMetadata;
        }
        field(11; "Error Code"; Code[20])
        {
            Caption = 'Error Code';
            DataClassification = SystemMetadata;
        }
        field(12; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            DataClassification = SystemMetadata;
            MinValue = 0;
        }
        field(13; "Created At"; DateTime)
        {
            Caption = 'Created At';
            DataClassification = SystemMetadata;
        }
        field(14; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Message ID")
        {
            Clustered = true;
        }
        key(SK1; "Idempotency Key")
        {
            Unique = true;
        }
        key(SK2; "Correlation ID")
        {
        }
        key(SK3; Status, "Type")
        {
        }
    }

    trigger OnInsert()
    begin
        if IsNullGuid("Message ID") then
            "Message ID" := CreateGuid();
        if IsNullGuid("Correlation ID") then
            "Correlation ID" := CreateGuid();
        "Created At" := CurrentDateTime();
    end;

    procedure SetRequestContent(Content: Text)
    var
        OutStr: OutStream;
    begin
        "Request Content".CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Content);
    end;

    procedure GetRequestContent(): Text
    var
        InStr: InStream;
        Content: Text;
        Line: Text;
    begin
        CalcFields("Request Content");
        if not "Request Content".HasValue() then
            exit('');
        "Request Content".CreateInStream(InStr, TextEncoding::UTF8);
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            Content += Line;
        end;
        exit(Content);
    end;

    procedure SetResponseContent(Content: Text)
    var
        OutStr: OutStream;
    begin
        "Response Content".CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Content);
    end;

    procedure GetResponseContent(): Text
    var
        InStr: InStream;
        Content: Text;
        Line: Text;
    begin
        CalcFields("Response Content");
        if not "Response Content".HasValue() then
            exit('');
        "Response Content".CreateInStream(InStr, TextEncoding::UTF8);
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            Content += Line;
        end;
        exit(Content);
    end;

    procedure SetErrorContent(Content: Text)
    var
        OutStr: OutStream;
    begin
        "Error Content".CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Content);
    end;

    procedure GetErrorContent(): Text
    var
        InStr: InStream;
        Content: Text;
        Line: Text;
    begin
        CalcFields("Error Content");
        if not "Error Content".HasValue() then
            exit('');
        "Error Content".CreateInStream(InStr, TextEncoding::UTF8);
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            Content += Line;
        end;
        exit(Content);
    end;
}
