// The error-isolation boundary for handler execution. The dispatcher runs this
// codeunit with Codeunit.Run, so anything the handler does happens in its own
// transaction: if it raises an error, only the handler's own writes roll back, and
// the dispatcher (which already committed the In Progress state) can then record
// the failure durably. Resolving the handler from the Type enum here keeps the
// dispatch one line and free of any CASE statement.
//
// TableNo binds Rec to the Integration Message being processed.
codeunit 73298412 "Integration Handler Runner"
{
    Access = Public;
    TableNo = "Integration Message";

    trigger OnRun()
    var
        Handler: Interface IIntegrationHandler;
    begin
        // The enum implements the interface, so this assignment resolves the bound
        // handler with no lookup table and no CASE.
        Handler := Rec.Type;
        Handler.Process(Rec);
    end;
}
