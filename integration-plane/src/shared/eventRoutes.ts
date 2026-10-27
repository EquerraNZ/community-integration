/**
 * Which external business event goes on which queue, as data.
 *
 * It is a table rather than a `switch` for two reasons. Adding an event in BC
 * becomes adding a row. And the subscription health check derives its expected
 * set from this same table (`expectedSubscriptions`), so adding a route cannot
 * leave the check behind: a second hand-written list would be correct the day it
 * was written and silently wrong afterwards, which is the exact failure mode the
 * check exists to catch.
 */

import { config } from "./config.js";
import type { EventSubscription } from "./bcClient.js";
import type { Flow } from "./envelope.js";

export interface EventRoute {
  eventName: string;
  queueName: string;
  flow: Flow;
  /** The field in the event payload that is this flow's stable id. */
  businessKeyField: string;
  /** Where to take the correlation id from, when the event carries one. */
  correlationField: string;
}

export const EVENT_ROUTES: readonly EventRoute[] = [
  {
    eventName: "OnSalesOrderReleased_v1",
    queueName: "outbound-wms-fulfilment",
    flow: "wms-fulfilment",
    businessKeyField: "reference",
    correlationField: "correlationId",
  },
  {
    eventName: "OnShipmentConfirmed_v1",
    queueName: "outbound-webstore-status",
    flow: "webstore-status",
    businessKeyField: "orderNo",
    correlationField: "correlationId",
  },
];

export function routeFor(eventName: string): EventRoute | undefined {
  return EVENT_ROUTES.find((route) => route.eventName === eventName);
}

/**
 * What the plane expects to be subscribed to in BC, derived from the routes it
 * can actually handle. Subscribing to an event with no route would deliver
 * messages nowhere.
 */
export function expectedSubscriptions(): EventSubscription[] {
  const notificationUrl = config.bcEventEndpointUrl();
  return EVENT_ROUTES.map((route) => ({ eventName: route.eventName, notificationUrl }));
}
