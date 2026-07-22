page 73298445 "Integration Expected Subs."
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Integration Expected Subscr.";
    Caption = 'Integration Expected Subscriptions';

    layout
    {
        area(Content)
        {
            repeater(Expected)
            {
                field("Event Name"; Rec."Event Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the external business event that must stay subscribed.';
                }
                field("Notification URL"; Rec."Notification URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the notification endpoint the subscription should point at.';
                }
            }
        }
    }
}
