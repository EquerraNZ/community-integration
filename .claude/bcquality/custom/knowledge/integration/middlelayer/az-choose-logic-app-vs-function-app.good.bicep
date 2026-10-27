// Best practice: a Logic App orchestrates the flow over managed connectors (SFTP -> stage to BC)
// and hands the one hard step, parsing and reshaping the supplier's flat file, to a Function. The
// plumbing keeps the connectors, retry, and run history; the computation stays in unit-testable code.

resource orchestrator 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-supplier-feed'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      triggers: { on_new_sftp_file: { type: 'ApiConnection' } }
      actions: {
        Transform_File: {
          // Delegates the complex parse/reshape to the Function below.
          type: 'Function'
          inputs: { function: { id: parseFunction.id }, body: '@triggerBody()' }
        }
        Stage_To_BC: {
          type: 'Http'
          runAfter: { Transform_File: ['Succeeded'] }
          inputs: { method: 'POST', uri: bcStagingUri, body: '@body(\'Transform_File\')' }
        }
      }
    }
  }
}

resource parseFunction 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: functionApp
  name: 'ParseSupplierFlatFile'   // custom code: the gnarly transform lives here, tested in isolation
}
