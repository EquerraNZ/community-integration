/**
 * The Function App entry point. Importing a function module runs its `app.*`
 * registration, so every function the plane exposes is listed here and nowhere
 * else. A function that is not imported here does not exist at run time, which
 * is the one failure that looks like a deployment problem and is not.
 */

import "./functions/receiveWebstoreOrder.js";
import "./functions/receiveWmsShipment.js";
import "./functions/receiveBusinessEvent.js";
import "./functions/stageWebstoreOrder.js";
import "./functions/stageWmsShipment.js";
import "./functions/sendWmsFulfilment.js";
import "./functions/sendWebstoreStatus.js";
import "./functions/checkSubscriptionHealth.js";
