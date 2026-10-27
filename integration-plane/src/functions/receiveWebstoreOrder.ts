/**
 * The storefront's ingest endpoint. Business process 1, first hop.
 *
 * It answers before anything touches BC, so a shopper's checkout never waits on
 * Business Central posting, and never fails because BC is mid-upgrade.
 */

import { app, type HttpRequest, type HttpResponseInit, type InvocationContext } from "@azure/functions";
import { handleReceive, type ReceiverConfig } from "../shared/receiver.js";

const CONFIG: ReceiverConfig = {
  flow: "webstore-order",
  source: "webstore",
  queueName: "inbound-webstore-order",
  apiKeySettingName: "WEBSTORE_INGEST_KEY",
  businessKeyField: "orderNo",
};

export async function receiveWebstoreOrder(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  return handleReceive(CONFIG, request, context);
}

app.http("receiveWebstoreOrder", {
  methods: ["POST"],
  // Anonymous at the platform level because the storefront authenticates with a
  // shared key in a header, which is what it offers. The key is checked in
  // `handleReceive` against the Key Vault value.
  authLevel: "anonymous",
  route: "webstore/orders",
  handler: receiveWebstoreOrder,
});
