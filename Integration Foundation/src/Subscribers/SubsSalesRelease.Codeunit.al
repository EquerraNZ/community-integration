codeunit 73298432 "Subs-Sales Release"
{
    // Single-purpose, thin subscriber for the sales-release area. It does no business
    // logic inline: it exits early on every precondition and delegates the work to
    // the fulfilment management codeunit.

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnAfterReleaseSalesDoc', '', false, false)]
    local procedure ReleaseSalesDocument_OnAfterReleaseSalesDoc(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; LinesWereModified: Boolean)
    var
        FulfilmentRequestMgt: Codeunit "Fulfilment Request Mgt.";
    begin
        if PreviewMode then
            exit;
        if SalesHeader.IsTemporary() then
            exit;
        if Session.CurrentExecutionMode <> ExecutionMode::Standard then
            exit;
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit;
        FulfilmentRequestMgt.RequestFulfilment(SalesHeader);
    end;
}
