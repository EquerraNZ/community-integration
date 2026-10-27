# Anti-pattern: subscriptions are created once at deploy time and never checked again. There is no
# renewal before the ~3-day lease expires and no alert when BC silently removes a subscription after
# a few bad responses. Events stop arriving quietly; the gap is found days later as stale data.

param(
    [string[]] $EventNames = @('SalesShipmentPosted', 'ItemAvailabilityChanged')
)

# Runs only at provisioning. Nothing lists, renews, reconciles, or alerts afterwards.
foreach ($name in $EventNames) {
    New-BcEventSubscription -EventName $name
}
