---
bc-version: [all]
domain: integration
keywords: [azure, logic-app, function-app, orchestration, connectors, custom-code, component-selection, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Choose a Logic App or a Function by the nature of the work

## Description

Logic Apps and Function Apps are both ways to run plane logic, and the choice is about the nature of the work, not preference. A Logic App is a declarative workflow: a visual graph of triggers and actions with hundreds of managed connectors (SharePoint, SQL, SAP, Dynamics, Service Bus, SFTP) and built-in retry, scheduling, and run history. It shines at orchestration and system-to-system plumbing where the value is wiring connectors together and the logic is mostly sequencing and routing. A Function is custom code: it wins when the work is genuine computation, non-trivial data transformation, complex branching, a custom protocol, a library the connectors do not cover, or latency-sensitive processing where a per-action billing model and connector overhead would hurt.

Choosing wrongly shows up as friction. Complex transformation logic crammed into Logic App expressions becomes an unreadable, untestable `@concat/@if` soup; simple connector plumbing rewritten as hand-coded HTTP and auth in a Function throws away the retry, the run history, and the connector that would have been three clicks.

## Best Practice

Reach for a **Logic App** when the flow is orchestration over managed connectors: pull a file from SFTP, transform lightly, stage to BC, notify Teams, with retry and run history you get for free and a graph a non-developer can follow. Reach for a **Function** when the work is code: parsing and reshaping a gnarly payload, running an algorithm, calling a system with no connector, or meeting a latency/throughput target. Compose them, a Logic App orchestrates the flow and calls a Function for the one hard transformation step, so each does what it is best at and the custom code stays unit-testable. Keep business transforms out of Logic App expression language. See `az-choose-logic-app-vs-function-app.good.bicep`.

## Anti Pattern

A Logic App carrying substantial business logic in chained expressions and nested conditions (untestable, unreadable, and a nightmare to change), or a Function that hand-rolls connector-style plumbing, custom HTTP, auth, retry, polling, that a Logic App connector provides out of the box. The detection signal: deep `@`-expression logic or large inline data transforms inside a workflow definition, or a Function reimplementing retry/scheduling/connector behaviour the platform already offers. Move computation into a Function; move plumbing into a Logic App. See `az-choose-logic-app-vs-function-app.bad.bicep`.

## See also

- `az-choose-messaging-service.md`
- `az-retry-in-plane.md`
- `az-durable-retry-not-tight-loop.md`
