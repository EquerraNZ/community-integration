// Best practice: on 202 Accepted, PARK the message as In Progress with the status URL on
// the row, then let a scheduled poll resume it. Error state lives on the MESSAGE,
// so a resume after a restart still knows why it last failed.

codeunit 50200 "Long Running Start"
{
    procedure Start(var IntegrationMessage: Record "Integration Message")
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Location: array[1] of Text;
    begin
        Client.Post('https://svc.contoso.com/api/jobs', BuildContent(IntegrationMessage), Response);

        // 202 means "accepted, answer later". Treat it as a DEFERRAL, not a failure to retry and
        // not a completion. Re-sending the request here would duplicate work the service already took.
        if Response.HttpStatusCode() = 202 then begin
            Response.Headers().GetValues('Location', Location);
            // Store the status URL on the row and park it. The flow now lives in the database,
            // not in this session, so it survives the session ending.
            IntegrationMessage."Status URL" := CopyStr(Location[1], 1, 250);
            IntegrationMessage.Status := IntegrationMessage.Status::"In Progress";
            IntegrationMessage.Modify(true);
        end;

        // Start returns immediately. Work that waits more than ~30s belongs to external
        // orchestration (a Logic App / Durable Function) or a brief scheduled poll, NEVER a
        // Job Queue tight loop. The Job Queue owns short, BC-bounded units of work.
    end;
}

codeunit 50201 "Long Running Resume"
{
    TableNo = "Job Queue Entry";

    // Runs on a schedule. Each invocation does a quick pass over parked rows and returns; it does
    // not sit and wait. A flow that is still pending simply gets picked up again next run.
    procedure ResumeAwaiting()
    var
        IntegrationMessage: Record "Integration Message";
        Client: HttpClient;
        Response: HttpResponseMessage;
    begin
        IntegrationMessage.SetRange(Status, IntegrationMessage.Status::"In Progress");
        if IntegrationMessage.FindSet() then
            repeat
                if Client.Get(IntegrationMessage."Status URL", Response) and IsComplete(Response) then
                    Complete(IntegrationMessage)
                else begin
                    // Error state lives ON THE MESSAGE, not in a variable. A resume in
                    // a different session after a restart still sees the true failure context.
                    IntegrationMessage."Error Code" := 'POLL-RETRY';
                    IntegrationMessage.SetErrorContent(LastError(Response));
                    IntegrationMessage.Modify(true);
                end;
            until IntegrationMessage.Next() = 0;
    end;
}
