enumextension 73298472 "Test Message Types" extends "Integration Message Type"
{
    // Test-only routing values, well outside the production ordinals, so the dispatcher
    // and handler paths can be exercised without a real integration.
    value(950; TestSucceed)
    {
        Caption = 'Test Succeed';
        Implementation = "IIntegrationMessageHandler" = "Test Integration Handler";
    }
    value(951; TestFailPermanent)
    {
        Caption = 'Test Fail Permanent';
        Implementation = "IIntegrationMessageHandler" = "Test Integration Handler";
    }
    value(952; TestFailTransient)
    {
        Caption = 'Test Fail Transient';
        Implementation = "IIntegrationMessageHandler" = "Test Integration Handler";
    }
}
