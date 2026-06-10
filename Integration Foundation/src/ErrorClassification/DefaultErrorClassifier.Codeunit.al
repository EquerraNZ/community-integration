// The shipped default classifier. Deliberately simple: it matches the captured
// error text against a small set of keywords that usually indicate a transient
// condition (timeouts, connection resets, throttling, "temporarily unavailable").
// Anything it does not recognise as transient it treats as Permanent, because the
// safe default is to stop retrying and ask a human rather than hammer a downstream
// system with a request that will never succeed.
//
// This is the seam, not the destination. It carries no external dependency. A
// consuming app that wants smarter classification (an AI model, a richer rule set)
// implements IErrorClassifier in its own codeunit, binds it to an "Error Classifier
// Type" value, and selects it in setup. Nothing here changes.
codeunit 73298416 "Default Error Classifier" implements IErrorClassifier
{
    Access = Public;

    var
        MessageMgt: Codeunit "Integration Message Mgt.";

    procedure Classify(var IntegrationMessage: Record "Integration Message"): Enum "Integration Error Class"
    var
        ErrorText: Text;
    begin
        ErrorText := MessageMgt.GetErrorText(IntegrationMessage).ToLower();

        if LooksTransient(ErrorText) then
            exit("Integration Error Class"::Transient);

        exit("Integration Error Class"::Permanent);
    end;

    local procedure LooksTransient(LowerErrorText: Text): Boolean
    var
        TransientMarker: Text;
        Markers: List of [Text];
    begin
        Markers.Add('timeout');
        Markers.Add('timed out');
        Markers.Add('temporarily unavailable');
        Markers.Add('connection reset');
        Markers.Add('connection was closed');
        Markers.Add('too many requests');
        Markers.Add('throttl');
        Markers.Add('service unavailable');
        Markers.Add('try again');
        Markers.Add('deadlock');

        foreach TransientMarker in Markers do
            if StrPos(LowerErrorText, TransientMarker) > 0 then
                exit(true);

        exit(false);
    end;
}
