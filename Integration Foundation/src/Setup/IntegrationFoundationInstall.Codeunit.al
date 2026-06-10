// Install logic. Seeds the single-instance setup and cue records so a fresh install
// has sane defaults (the rule-based classifier active, a small retry limit) and the
// Activities cue can render immediately. Seeding here, rather than lazily on first
// use, keeps the runtime paths free of get-or-create checks.
codeunit 73298422 "Integration Foundation Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
        SeedSetup();
        SeedCue();
    end;

    local procedure SeedSetup()
    var
        IntegrationSetup: Record "Integration Setup";
    begin
        if IntegrationSetup.Get() then
            exit;
        IntegrationSetup.Init();
        // Default classifier active; the InitValue properties on the table supply
        // the retry limit and stale-lock defaults.
        IntegrationSetup."Active Error Classifier" := IntegrationSetup."Active Error Classifier"::Default;
        IntegrationSetup.Insert();
    end;

    local procedure SeedCue()
    var
        IntegrationCue: Record "Integration Cue";
    begin
        if IntegrationCue.Get() then
            exit;
        IntegrationCue.Init();
        IntegrationCue.Insert();
    end;
}
