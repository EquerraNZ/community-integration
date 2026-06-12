enumextension 73298490 "Test Integration Msg. Type" extends "Integration Message Type"
{
    value(73298490; "Test")
    {
        Caption = 'Test';
        Implementation = "IIntegration Msg. Processor" = "Test Integration Msg. Proc.";
    }
    value(73298491; "Test Failing")
    {
        Caption = 'Test Failing';
        Implementation = "IIntegration Msg. Processor" = "Test Int. Msg. Proc. Fail";
    }
}
