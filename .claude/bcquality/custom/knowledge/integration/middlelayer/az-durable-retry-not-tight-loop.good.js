// Best practice: a Durable Functions orchestrator schedules the backoff with createTimer. Between
// attempts the orchestration sleeps without holding a worker, and it resumes replay-safe after a
// host restart or deployment. The idempotency key rides on the orchestration input, so the attempt
// that fires tomorrow carries the same key as today's.

const df = require("durable-functions");

module.exports = df.orchestrator(function* (context) {
    const input = context.df.getInput(); // { payload, idempotencyKey }
    const maxAttempts = 6;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const result = yield context.df.callActivity("CallExternalSystem", input);
        if (result.ok) {
            return result;
        }
        if (!result.transient) {
            yield context.df.callActivity("DeadLetter", input);
            return result;
        }
        // Exponential backoff that can stretch to hours. The orchestration is unloaded while it waits.
        const delayMinutes = Math.min(60 * 4, Math.pow(2, attempt));
        const fireAt = new Date(context.df.currentUtcDateTime.getTime() + delayMinutes * 60 * 1000);
        yield context.df.createTimer(fireAt);
    }

    yield context.df.callActivity("DeadLetter", input);
});
