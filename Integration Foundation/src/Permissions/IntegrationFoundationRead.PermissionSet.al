// Read-only access for operations viewers who should inspect the integration queue
// but not change it. Data permission is read-only (R), so even though the pages and
// their actions are reachable, any recovery write (retry, resolve, reassign) is
// blocked at the data layer. Execute permission on the objects is granted so the
// pages open and the payload/error viewers work.
permissionset 73298461 "Integration Foundation - Read"
{
    Assignable = true;
    Caption = 'Integration Foundation - Read';

    Permissions =
        tabledata "Integration Message" = R,
        tabledata "Integration Setup" = R,
        tabledata "Integration Message Log" = R,
        tabledata "Integration Cue" = R,
        table "Integration Message" = X,
        table "Integration Setup" = X,
        table "Integration Message Log" = X,
        table "Integration Cue" = X,
        codeunit "Integration Message Mgt." = X,
        codeunit "Integration Telemetry" = X,
        codeunit "Integration Idempotency Mgt." = X,
        page "Integration Messages" = X,
        page "Integration Message Card" = X,
        page "Integration Message Log Part" = X,
        page "Integration Activities" = X,
        page "Integration Setup" = X;
}
