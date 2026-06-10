// The pipeline stages. Extensible and "implements" the stage interface, the same
// way the integration type binds to a handler: a consuming app adds its ordered
// stages with an enumextension, each bound to a stage codeunit, for example:
//
//   enumextension 50110 "My Pipeline" extends "Integration Stage"
//   {
//       value(50110; ValidatePayload)   { Implementation = IIntegrationStage = "My Validate Stage"; }
//       value(50120; CreateDocument)    { Implementation = IIntegrationStage = "My Create Stage"; }
//       value(50130; PostDocument)      { Implementation = IIntegrationStage = "My Post Stage"; }
//   }
//
// Each stage's GetNextStage names the following value (the last returns Completed).
// The two framework values are sentinels, never run as real work:
//   None      the message is not in a pipeline (a single-handler message).
//   Completed the pipeline has finished; the engine resolves the message.
enum 73298444 "Integration Stage" implements IIntegrationStage
{
    Extensible = true;
    Caption = 'Integration Stage';
    DefaultImplementation = IIntegrationStage = "Integration Terminal Stage";

    value(0; None)
    {
        Caption = 'None';
        Implementation = IIntegrationStage = "Integration Terminal Stage";
    }
    value(99; Completed)
    {
        Caption = 'Completed';
        Implementation = IIntegrationStage = "Integration Terminal Stage";
    }
}
