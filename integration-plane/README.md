# integration-plane/

The Azure half of the solution: the Function App that terminates every external
connection, holds every external credential, and carries every message to and from
Business Central. The extension makes no outbound HTTP call by design, so without
this nothing reaches BC and nothing leaves it.

What it is and why it is shaped this way is in `specs/tech-design.md` under "Azure
integration layer". The infrastructure it runs on is in `infra/`.

## The shape

Every flow is the same four steps, and only the adapters differ:
**receive and acknowledge, queue, deliver, record.**

| Function | Trigger | Does |
|---|---|---|
| `receiveWebstoreOrder` | `POST /api/webstore/orders` | Authenticate the storefront, enqueue, answer `202`. No BC call. |
| `receiveWmsShipment` | `POST /api/wms/shipments` | The same for the WMS confirmation callback. |
| `receiveBusinessEvent` | `POST /api/bc/events` | Answer BC's subscription handshake, route each event onto its queue. |
| `stageWebstoreOrder` | queue `inbound-webstore-order` | POST the envelope to the BC API page as `WebstoreOrder`. |
| `stageWmsShipment` | queue `inbound-wms-shipment` | The same as `WmsShipmentConfirmation`. |
| `sendWmsFulfilment` | queue `outbound-wms-fulfilment` | Read the staged DTO back from BC, POST it to the WMS, record the `wmsRef`. |
| `sendWebstoreStatus` | queue `outbound-webstore-status` | PATCH the storefront order to `Despatched`. |
| `checkSubscriptionHealth` | timer, every 6 hours | List BC's event subscriptions, re-register a missing one, alert. |

`src/shared/` holds what all of them reuse. A new integration is a receiver, a
sender, and a row in `eventRoutes.ts`; if it needs more than that, the shared layer
is the thing to change, not the new flow.

## Running it

```bash
npm install
cp local.settings.example.json local.settings.json   # then fill it in
npm test
npm start
```

`local.settings.json` is git-ignored and must stay that way. In Azure these are app
settings, and every secret is a Key Vault reference rather than a value.

## Four things that will bite you if you change this

**The retry budget is the queue's delivery count, and only that.** `host.json` sets
the Functions host retry policy to a single attempt on purpose. Two retry
mechanisms multiply: five deliveries times five host retries is twenty-five calls
to a struggling external system, which is how a retry policy turns an outage into
an incident.

**A permanent failure is parked, not thrown.** The Node worker does not expose
Service Bus message settlement, so a function cannot dead-letter the message it is
holding: its only choices are complete (return) or abandon (throw). Throwing on a
4xx would retry it five times, which the Azure integration review calls a blocker.
So `queueStep.ts` parks it on the `parked` queue with its reason and completes it.
Operationally the parked queue and the dead-letter queues are one surface:
messages that stopped, with the reason attached.

**A `409` from BC is success.** BC deduplicated on `(External Reference, Type)`,
which is exactly what it was asked to do. Treating it as a failure would park every
legitimate redelivery, and redelivery is normal.

**The correlation id is never invented.** It is read from the caller, or derived
from the message's own business key. A fresh GUID here would be a trace id that
joins nothing, which is worse than having none because it looks like it works.

## Testing

```bash
npm test
```

Unit tests over everything that is pure logic, which is where the rules live:
classification, the envelope and its `MessageId`, correlation, configuration
failure, the BC client's response mapping, both receivers, both stagers, the event
router, both senders, and the subscription comparison. They need no Azure and no BC.

What they deliberately do not cover, because a unit test would only assert the
mock: that the resources exist, that no secret is in the template, that
dead-lettering and the alerts behave. Those are verified by deploying into an empty
resource group, and by `azure-integration-validator` reading `infra/`.
