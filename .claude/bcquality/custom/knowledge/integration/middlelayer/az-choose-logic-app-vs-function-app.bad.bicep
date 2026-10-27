// Anti-pattern: the whole supplier flat-file transform is crammed into Logic App expression language,
// nested @split/@if/@concat over every line. It cannot be unit-tested, it is unreadable in the
// designer, and a small format change means editing expression soup by hand. This computation belongs
// in a Function; the Logic App should only orchestrate.

resource orchestrator 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-supplier-feed'
  location: location
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      triggers: { on_new_sftp_file: { type: 'ApiConnection' } }
      actions: {
        Parse_In_Expressions: {
          type: 'Compose'
          inputs: '@map(split(triggerBody(), decodeUriComponent(\'%0A\')), item => if(greater(length(split(item, \',\')), 3), concat(\'{"sku":"\', split(item, \',\')[0], \'","qty":\', split(item, \',\')[2], \',"price":\', split(item, \',\')[3], \'}\'), \'\'))'
        }
        Stage_To_BC: {
          type: 'Http'
          runAfter: { Parse_In_Expressions: ['Succeeded'] }
          inputs: { method: 'POST', uri: bcStagingUri, body: '@outputs(\'Parse_In_Expressions\')' }
        }
      }
    }
  }
}
