// The integration type drives dispatch. It is an extensible enum that "implements"
// the handler interface: each value names the codeunit that handles it. A consuming
// app adds its own value with an enumextension and binds its handler in the same
// declaration, for example:
//
//   enumextension 50100 "My Types" extends "Integration Type"
//   {
//       value(50100; SalesOrderImport)
//       {
//           Caption = 'Sales Order Import';
//           Implementation = IIntegrationHandler = "My Sales Order Handler";
//       }
//   }
//
// The dispatcher then does `Handler := Message.Type;` and calls `Handler.Process`.
// No framework object is touched. The shipped Unspecified value is the safety net:
// it routes to a handler that raises a clear "no handler registered" error.
enum 73298443 "Integration Type" implements IIntegrationHandler
{
    Extensible = true;
    Caption = 'Integration Type';
    DefaultImplementation = IIntegrationHandler = "Default Integration Handler";

    value(0; Unspecified)
    {
        Caption = 'Unspecified';
        Implementation = IIntegrationHandler = "Default Integration Handler";
    }
}
