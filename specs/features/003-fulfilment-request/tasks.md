# Feature Tasks: 003-fulfilment-request

- **Feature id:** 003-fulfilment-request
- **Plan:** ./plan.md
- **Status:** done

## Tasks

- [x] 1. Create table "WMS Setup" (73298450): singleton with Location Code, Shipping Method, SKU Source.
- [x] 2. Create card page "WMS Setup" (73298450): admin page with auto-insert on open.
- [x] 3. Create enumextension "Fulfilment Request Type" (73298450): add value "Fulfilment Request" (73298450) to Integration Message Type with Implementation = "Fulfilment Req. Processor".
- [x] 4. Create codeunit "Fulfilment Req. Processor" (73298450): implements IIntegration Msg. Processor with a no-op Process (outbound-only type, processing is not needed).
- [x] 5. Create codeunit "Integration Events" (73298452): holds the [BusinessEvent] procedure OnAfterFulfilmentRequested(CorrelationId: Text; Payload: Text).
- [x] 6. Create codeunit "Fulfilment Request Mgt." (73298451): subscribes to OnAfterReleaseSalesDoc, builds the fulfilment payload JSON, stages an outbound Integration Message, and calls the business event.
- [x] 7. Write AL test codeunit covering all acceptance criteria: message created on release, correct payload schema, reverse SKU in payload, unmapped item fails, missing setup fails, business event fires, telemetry emitted.
- [x] 8. Build and resolve any compiler errors.
- [x] 9. Run mandatory verifier set and resolve findings.
- [x] 10. Update roadmap item to `done`.
