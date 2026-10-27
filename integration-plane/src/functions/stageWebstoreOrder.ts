/**
 * Stage a queued Webstore order into Business Central. Business process 1,
 * second hop.
 */

import { app, type InvocationContext } from "@azure/functions";
import { handleStage, type StagerConfig } from "../shared/stager.js";

const CONFIG: StagerConfig = { flow: "webstore-order", messageType: "WebstoreOrder" };

export async function stageWebstoreOrder(message: unknown, context: InvocationContext): Promise<void> {
  await handleStage(CONFIG, message, context);
}

app.serviceBusQueue("stageWebstoreOrder", {
  queueName: "inbound-webstore-order",
  connection: "SERVICEBUS",
  handler: stageWebstoreOrder,
});
