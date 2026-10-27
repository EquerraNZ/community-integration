---
bc-version: [all]
domain: integration
keywords: [azure, application-insights, telemetry, observability, logging, monitoring, middle-layer]
technologies: [bicep]
countries: [w1]
application-area: [all]
---

# Wire observability into every plane component

## Description

An integration plane with no telemetry is a black box, and integrations fail quietly: a subscription expires, a connector's credential lapses, a downstream starts returning 500s at 2am. If the Functions and Logic Apps that run the flow have no Application Insights (or equivalent) attached, the first anyone hears of it is a user noticing data stopped arriving, days later, with no trace to reconstruct what happened. Observability is not an add-on for the plane, it is the only way to answer "is it still working" and "why did it stop." Every component that processes a message, and the resources it depends on, must emit telemetry to a sink that is retained, queryable, and alerted on.

This is the infrastructure that makes correlation (`az-correlation-header.md`) and subscription health (`az-subscription-health-check.md`) usable: the correlation id is only as good as the log it lands in, and a health check only helps if its results are visible.

## Best Practice

Provision Application Insights and bind it to every Function app and Logic App in the plane (for Functions, the `APPLICATIONINSIGHTS_CONNECTION_STRING` app setting; for Logic App Standard, the workspace-based connection). Turn on diagnostic settings that route resource logs and metrics to a Log Analytics workspace, and define alerts on the signals that matter: run failures, DLQ depth, dependency failure rate, and latency. Keep the retention long enough to investigate an incident that is noticed late. See `az-observability-wired.good.bicep`.

## Anti Pattern

A Function app or Logic App deployed with no Application Insights connection and no diagnostic settings, so its runs, failures, and dependencies emit nothing durable. The detection signal: a `Microsoft.Web/sites` (functionapp) or `Microsoft.Logic/workflows` resource with no linked Application Insights/monitoring configuration and no `Microsoft.Insights/diagnosticSettings` for the integration resources. The consequence is a plane that cannot be debugged after the fact and failures that are discovered by users rather than by alerts. See `az-observability-wired.bad.bicep`.

## See also

- `az-correlation-header.md`
- `az-subscription-health-check.md`
- `al-monitor-external-event-subscription-health.md`
