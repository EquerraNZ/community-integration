/**
 * The WMS shipment confirmation callback. Business process 3, first hop.
 *
 * Keyed on `shipmentId` and correlated on `reference`, and the two are
 * deliberately different: the shipment id is what must not post twice, and the
 * order number is what joins this hop to the rest of the order's history.
 */

import { app, type HttpRequest, type HttpResponseInit, type InvocationContext } from "@azure/functions";
import { handleReceive, type ReceiverConfig } from "../shared/receiver.js";

const CONFIG: ReceiverConfig = {
  flow: "wms-shipment",
  source: "wms",
  queueName: "inbound-wms-shipment",
  apiKeySettingName: "WMS_CALLBACK_KEY",
  businessKeyField: "shipmentId",
  correlationField: "reference",
};

export async function receiveWmsShipment(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  return handleReceive(CONFIG, request, context);
}

app.http("receiveWmsShipment", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "wms/shipments",
  handler: receiveWmsShipment,
});
