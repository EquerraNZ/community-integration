// Full access to the framework: read/write on all data and execute on every object.
// Grant this to administrators and to the service account a consuming integration
// runs under. Every object the extension defines is listed; nothing is left out, so
// a fresh install does not hit "permission denied" on an object the developer forgot.
permissionset 73298460 "Integration Foundation - Full"
{
    Assignable = true;
    Caption = 'Integration Foundation - Full';

    Permissions =
        tabledata "Integration Message" = RIMD,
        tabledata "Integration Setup" = RIMD,
        tabledata "Integration Message Log" = RIMD,
        tabledata "Integration Cue" = RI,
        table "Integration Message" = X,
        table "Integration Setup" = X,
        table "Integration Message Log" = X,
        table "Integration Cue" = X,
        codeunit "Integration Message Mgt." = X,
        codeunit "Integration Dispatcher" = X,
        codeunit "Integration Handler Runner" = X,
        codeunit "Integration Idempotency Mgt." = X,
        codeunit "Integration Error Handler" = X,
        codeunit "Integration Classifier Job" = X,
        codeunit "Default Error Classifier" = X,
        codeunit "Integration Reply Mgt." = X,
        codeunit "Integration Pipeline Engine" = X,
        codeunit "Integration Stage Runner" = X,
        codeunit "Integration Telemetry" = X,
        codeunit "Default Integration Handler" = X,
        codeunit "Integration Terminal Stage" = X,
        page "Integration Messages" = X,
        page "Integration Message Card" = X,
        page "Integration Setup" = X,
        page "Integration Message Log Part" = X,
        page "Integration Activities" = X,
        page "Integration Message Entity" = X;
}
