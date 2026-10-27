/**
 * Stage a queued WMS shipment confirmation into Business Central. Business
 * process 3, second hop.
 */

import { app, type InvocationContext } from "@azure/functions";
import { handleStage, type StagerConfig } from "../shared/stager.js";

const CONFIG: StagerConfig = { flow: "wms-shipment", messageType: "WmsShipmentConfirmation" };

export async function stageWmsShipment(message: unknown, context: InvocationContext): Promise<void> {
  await handleStage(CONFIG, message, context);
}

app.serviceBusQueue("stageWmsShipment", {
  queueName: "inbound-wms-shipment",
  connection: "SERVICEBUS",
  handler: stageWmsShipment,
});
