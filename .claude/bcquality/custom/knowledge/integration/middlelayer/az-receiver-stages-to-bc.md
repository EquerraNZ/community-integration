---
bc-version: [all]
domain: integration
keywords: [azure, webhook-receiver, logic-app, function, apim, staging, integration-message, middle-layer]
technologies: [json]
countries: [w1]
application-area: [all]
---

# Azure receivers stage to BC and return

## Description

The Azure integration plane is the middle layer that sits between Business Central and the systems it does not own: the webhook receiver that catches a storefront event, the Logic App that routes a shipment to a WMS, the Function that fronts a partner API. The load-bearing rule for every receiver in that layer is the mirror of the BC-side staging rule (`al-stage-every-integration-message.md`): a receiver validates the payload, writes one row to the BC Integration Message staging endpoint, and returns. It does not post, it does not run BC business logic inline, and it does not block the connection open while BC finishes processing.

A receiver that reaches past staging couples an external caller's HTTP request to a BC database transaction. A slow posting routine or a lock held inside BC then surfaces as a timeout at the storefront, and the storefront's own retry fires a second, uncommitted copy of the same work. Staging first is what keeps the plane's availability independent of BC's.

## Best Practice

Treat the receiver as phase one of a two-phase split: acceptance in the plane, processing in BC. The Logic App, Function, or APIM policy authenticates the caller, does a shape check on the body, calls the Integration Message API page with the raw payload and the source system's stable id, and returns the id to the caller. All real work (posting, document creation, enrichment) happens later in a BC Job Queue codeunit that reads staged rows by status, fully decoupled from the original request. See `az-receiver-stages-to-bc.good.json` for a Logic App that POSTs to the staging page and returns.

## Anti Pattern

A receiver workflow that, after catching the event, calls a BC posting action, invokes a second external service to enrich the message, or waits in a loop on a BC "is it done yet" endpoint before returning. The detection signal: a receiver definition whose action graph contains a BC posting/business call or a polling loop between the trigger and the response, rather than a single staging write followed by the response. The fix is structural, move the post and the callout into the BC Job Queue processor. See `az-receiver-stages-to-bc.bad.json`.

## See also

- `al-stage-every-integration-message.md`
- `az-receiver-acknowledges-fast.md`
- `az-forward-idempotency-key.md`
