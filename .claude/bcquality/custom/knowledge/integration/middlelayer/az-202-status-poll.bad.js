// Anti-pattern: after the 202 the function blocks on a tight poll loop inside a single invocation,
// sleeping on the request thread. The Function execution timeout fires long before an overnight
// operation completes, the worker is held open the whole time, and when the result finally lands
// there is no execution left to receive it.

const fetch = require("node-fetch");

module.exports = async function (context, input) {
    const submit = await fetch("https://wms.contoso.com/api/picks", {
        method: "POST",
        body: JSON.stringify(input.payload)
    });
    const statusUrl = submit.headers.get("Location");

    // Blocks here for hours on one live invocation.
    while (true) {
        const status = await (await fetch(statusUrl)).json();
        if (status.done) {
            return status.result;
        }
        await new Promise(r => setTimeout(r, 60 * 1000));
    }
};
