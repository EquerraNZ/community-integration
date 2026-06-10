// The error-isolation boundary for one stage, the pipeline twin of the handler
// runner. The engine runs this with Codeunit.Run so a failing stage rolls back only
// its own work, never the stages that already succeeded. The stage is resolved from
// the message's Current Stage cursor, so there is no CASE statement and adding a
// stage never touches this codeunit.
//
// TableNo binds Rec to the Integration Message being processed.
codeunit 73298419 "Integration Stage Runner"
{
    Access = Public;
    TableNo = "Integration Message";

    trigger OnRun()
    var
        Stage: Interface IIntegrationStage;
    begin
        Stage := Rec."Current Stage";
        Stage.Run(Rec);
    end;
}
