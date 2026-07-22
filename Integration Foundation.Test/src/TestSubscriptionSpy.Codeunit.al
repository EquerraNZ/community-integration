codeunit 73298473 "Test Subscription Spy"
{
    // Manual-binding spy for the subscription health monitor: supplies a live set and
    // counts missing-subscription alerts, so the monitor's diff can be asserted.
    SingleInstance = true;
    EventSubscriberInstance = Manual;

    var
        LiveKeys: List of [Text];
        MissingCount: Integer;

    procedure SetLive(NewLive: List of [Text])
    begin
        LiveKeys := NewLive;
    end;

    procedure GetMissingCount(): Integer
    begin
        exit(MissingCount);
    end;

    procedure ResetSpy()
    begin
        Clear(LiveKeys);
        MissingCount := 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Subscription Health Monitor", 'OnCollectLiveSubscriptions', '', false, false)]
    local procedure OnCollectLiveSubscriptions(var LiveSubscriptions: List of [Text])
    var
        LiveKey: Text;
    begin
        foreach LiveKey in LiveKeys do
            LiveSubscriptions.Add(LiveKey);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Subscription Health Monitor", 'OnMissingSubscription', '', false, false)]
    local procedure OnMissingSubscription(ExpectedSubscription: Record "Integration Expected Subscr.")
    begin
        MissingCount += 1;
    end;
}
