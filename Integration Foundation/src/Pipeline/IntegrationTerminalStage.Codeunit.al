// The sentinel implementation bound to the None and Completed stage values (and the
// enum's default). These are not real stages, so Run must never be reached for them
// in normal operation: the engine never runs None (those are single-handler
// messages) or Completed (the pipeline is finished). If Run is reached it means a
// pipeline was misconfigured, so it fails loudly rather than silently. GetNextStage
// returns Completed so any accidental advance terminates rather than loops.
codeunit 73298423 "Integration Terminal Stage" implements IIntegrationStage
{
    Access = Public;

    var
        TerminalStageErr: Label 'Stage %1 is a sentinel and has no work to run. Bind real stages to the "Integration Stage" enum.', Comment = '%1 = stage name';

    procedure Run(var IntegrationMessage: Record "Integration Message")
    begin
        Error(TerminalStageErr, Format(IntegrationMessage."Current Stage"));
    end;

    procedure GetNextStage(): Enum "Integration Stage"
    begin
        exit("Integration Stage"::Completed);
    end;
}
