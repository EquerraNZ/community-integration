# Best practice: a scheduled check lists the live BC subscriptions, reconciles them against the set
# the plane expects, renews any near expiry, recreates any missing, and alerts on drift. Runs on a
# timer well inside the ~3-day expiry window. Result is emitted to the plane's telemetry sink.

param(
    [string[]] $ExpectedEventNames = @('SalesShipmentPosted', 'ItemAvailabilityChanged'),
    [int]      $RenewWhenHoursLeft = 24
)

$live = Get-BcEventSubscriptions   # wraps the BC subscriptions API, auth via Managed Identity
$now  = Get-Date
$drift = @()

foreach ($name in $ExpectedEventNames) {
    $sub = $live | Where-Object { $_.eventName -eq $name }
    if (-not $sub) {
        $drift += "MISSING: $name"
        New-BcEventSubscription -EventName $name
        continue
    }
    if (($sub.expiresAt - $now).TotalHours -lt $RenewWhenHoursLeft) {
        Update-BcEventSubscription -Id $sub.id   # renew the lease before it lapses
    }
}

if ($drift.Count -gt 0) {
    # The alert is what catches a silently removed subscription.
    Send-PlaneAlert -Severity 'High' -Message ("Subscription drift: " + ($drift -join '; '))
}

Write-PlaneTelemetry -Event 'SubscriptionHealthCheck' -ExpectedCount $ExpectedEventNames.Count -LiveCount $live.Count -DriftCount $drift.Count
