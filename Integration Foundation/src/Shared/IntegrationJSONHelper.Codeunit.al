codeunit 73298429 "Integration JSON Helper"
{
    // Defensive JSON readers shared by the inbound handlers. A missing or null member
    // returns the type's empty value rather than erroring, so a handler reads a payload
    // without a tangle of Get/IsNull guards and decides for itself what is mandatory.
    Access = Internal;

    procedure TryParse(Payload: Text; var JsonObj: JsonObject): Boolean
    begin
        Clear(JsonObj);
        exit(JsonObj.ReadFrom(Payload));
    end;

    /// <summary>The current time as an ISO 8601 / round-trip string (format 9), the
    /// timestamp form the integration payloads use.</summary>
    procedure IsoNow(): Text
    begin
        exit(Format(CurrentDateTime(), 0, 9));
    end;

    procedure GetText(JsonObj: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    procedure GetDecimal(JsonObj: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(KeyName, Token) then
            exit(0);
        if not Token.IsValue() then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsDecimal());
    end;

    procedure GetObject(JsonObj: JsonObject; KeyName: Text; var Result: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        Clear(Result);
        if not JsonObj.Get(KeyName, Token) then
            exit(false);
        if not Token.IsObject() then
            exit(false);
        Result := Token.AsObject();
        exit(true);
    end;

    procedure GetArray(JsonObj: JsonObject; KeyName: Text; var Result: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        Clear(Result);
        if not JsonObj.Get(KeyName, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(false);
        Result := Token.AsArray();
        exit(true);
    end;
}
