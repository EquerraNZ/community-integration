// A single stage in a durable pipeline. A multi-step flow is split into stages so
// each runs as its own short unit of work with its own lock window and its own
// retry, instead of one long handler holding one big lock that rolls back
// everything on any failure. Each stage knows only its own work and which stage
// comes next; the engine moves the cursor.
interface IIntegrationStage
{
    /// <summary>
    /// Do this stage's work for the message. Runs inside a Codeunit.Run isolation
    /// boundary, so a failure rolls back only this stage's work; the stages that
    /// already ran are untouched and are never re-run. To spawn downstream work,
    /// use Integration Message Mgt. to create a child that points back at this
    /// message via Parent Message ID.
    /// </summary>
    procedure Run(var IntegrationMessage: Record "Integration Message")

    /// <summary>
    /// The stage to advance to once this one succeeds. Return the Completed
    /// sentinel from the last stage; the engine then resolves the message.
    /// </summary>
    procedure GetNextStage(): Enum "Integration Stage"
}
