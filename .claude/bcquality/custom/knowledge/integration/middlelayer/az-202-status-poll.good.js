// Best practice: on a 202 the orchestrator reads the status URL and parks, polling on a durable
// timer until the operation reports done, then writes the result back to the same BC Integration
// Message. The orchestration is unloaded between polls; no worker is held open, and the total wait
// is bounded so a stuck operation dead-letters instead of polling forever.

const df = require("durable-functions");

module.exports = df.orchestrator(function* (context) {
    const input = context.df.getInput(); // { payload, bcMessageId, idempotencyKey }

    const submit = yield context.df.callActivity("SubmitToExternal", input);
    // submit => { statusUrl } after a 202 Accepted.

    const deadline = new Date(context.df.currentUtcDateTime.getTime() + 6 * 60 * 60 * 1000);
    while (context.df.currentUtcDateTime < deadline) {
        const status = yield context.df.callActivity("PollStatus", submit.statusUrl);
        if (status.done) {
            yield context.df.callActivity("WriteBackToBc", {
                bcMessageId: input.bcMessageId,
                result: status.result
            });
            return;
        }
        const next = new Date(context.df.currentUtcDateTime.getTime() + 60 * 1000);
        yield context.df.createTimer(next); // parked, no compute held
    }

    yield context.df.callActivity("DeadLetterOnTimeout", input);
});
