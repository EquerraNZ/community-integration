// Anti-pattern: a plain Function sleeps on a live invocation to pass the backoff. The worker is held
// open for hours doing nothing, the function will hit its execution timeout long before the loop
// finishes, and if the host recycles mid-wait the whole retry state is lost. A fresh guid per attempt
// also breaks idempotency, so a retry that does land double-applies.

const fetch = require("node-fetch");
const { randomUUID } = require("crypto");

module.exports = async function (context, payload) {
    const maxAttempts = 6;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const res = await fetch("https://partner.contoso.com/api/orders", {
            method: "POST",
            headers: { "Idempotency-Key": randomUUID() }, // changes every attempt
            body: JSON.stringify(payload)
        });
        if (res.ok) {
            return;
        }
        // Blocking sleep on the request thread, up to four hours.
        const delayMs = Math.min(60 * 60 * 4, Math.pow(2, attempt) * 60) * 1000;
        await new Promise(r => setTimeout(r, delayMs));
    }
};
