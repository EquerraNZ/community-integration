codeunit 73298424 "Integration Msg. Processor"
{
    // Runs one message's handler inside its own transaction. The dispatcher invokes
    // this with Codeunit.Run so a handler failure rolls back only that message's work
    // and leaves the batch intact. It does no routing logic of its own: the Type enum
    // resolves the handler polymorphically, so there is no CASE to grow per integration.
    TableNo = "Integration Message";

    trigger OnRun()
    var
        Handler: Interface "IIntegrationMessageHandler";
    begin
        Handler := Rec.Type;
        Handler.HandleMessage(Rec);
    end;
}
