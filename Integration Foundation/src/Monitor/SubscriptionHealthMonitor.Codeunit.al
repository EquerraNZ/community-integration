codeunit 73298435 "Subscription Health Monitor"
{
    // Scheduled Job Queue monitor. A dropped external event subscription is silent and
    // looks like a quiet feed, so the only way to catch it is to check actively and
    // diff the expected set against the live set. The live set is supplied through
    // OnCollectLiveSubscriptions rather than an HTTP call, keeping the extension free
    // of HttpClient per the constitution; the integration layer fills it.
    TableNo = "Job Queue Entry";

    var
        MissingSubscriptionTok: Label 'External event subscription missing.', Locked = true;
        MonitorRanTok: Label 'Subscription health monitor ran.', Locked = true;

    trigger OnRun()
    begin
        CheckHealth();
    end;

    /// <summary>
    /// Diff the expected subscriptions against the live set and alert on any that the
    /// platform has silently dropped. Public so it can be invoked directly in tests.
    /// </summary>
    procedure CheckHealth()
    var
        ExpectedSubscription: Record "Integration Expected Subscr.";
        LiveSubscriptions: List of [Text];
        ExpectedCount: Integer;
        MissingCount: Integer;
    begin
        OnCollectLiveSubscriptions(LiveSubscriptions);

        if ExpectedSubscription.FindSet() then
            repeat
                ExpectedCount += 1;
                if not LiveSubscriptions.Contains(SubscriptionKey(ExpectedSubscription."Event Name", ExpectedSubscription."Notification URL")) then begin
                    RaiseMissingSubscriptionAlert(ExpectedSubscription);
                    MissingCount += 1;
                end;
            until ExpectedSubscription.Next() = 0;

        LogMonitorRun(ExpectedCount, MissingCount);
    end;

    /// <summary>Build the comparison key for one subscription. Expected and live keys
    /// are compared on this exact string, so a live-set provider must match it.</summary>
    procedure SubscriptionKey(EventName: Text; NotificationUrl: Text): Text
    begin
        exit(StrSubstNo('%1|%2', EventName, NotificationUrl));
    end;

    local procedure RaiseMissingSubscriptionAlert(ExpectedSubscription: Record "Integration Expected Subscr.")
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('eventName', ExpectedSubscription."Event Name");
        Dimensions.Add('notificationUrl', ExpectedSubscription."Notification URL");
        Session.LogMessage('INT-0011', MissingSubscriptionTok, Verbosity::Warning,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
        OnMissingSubscription(ExpectedSubscription);
    end;

    local procedure LogMonitorRun(ExpectedCount: Integer; MissingCount: Integer)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('expectedCount', Format(ExpectedCount));
        Dimensions.Add('missingCount', Format(MissingCount));
        Session.LogMessage('INT-0012', MonitorRanTok, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    /// <summary>
    /// Supply the live external event subscription keys (format EventName|URL). The
    /// integration layer, which registered the subscriptions, subscribes here. With no
    /// subscriber the live set is empty, so the monitor reports every expected
    /// subscription as missing (fail loud, never silent).
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnCollectLiveSubscriptions(var LiveSubscriptions: List of [Text])
    begin
    end;

    /// <summary>Raised for each expected subscription found missing, so operations can
    /// wire an alert (email, Teams, ticket) without changing the core.</summary>
    [IntegrationEvent(false, false)]
    local procedure OnMissingSubscription(ExpectedSubscription: Record "Integration Expected Subscr.")
    begin
    end;
}
