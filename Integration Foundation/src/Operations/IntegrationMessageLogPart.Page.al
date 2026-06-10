// The audit-trail factbox shown on the message card. Read-only: the log is an
// append-only record of what happened to a message, including who ran each manual
// recovery action and when.
page 73298453 "Integration Message Log Part"
{
    PageType = ListPart;
    SourceTable = "Integration Message Log";
    Caption = 'Activity Log';
    ApplicationArea = All;
    Editable = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Logged At"; Rec."Logged At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this activity was recorded.';
                }
                field(Event; Rec.Event)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies what happened to the message.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the detail of the activity, such as the error text or the resolution reason.';
                }
                field("Logged By"; Rec."Logged By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who performed or triggered the activity.';
                }
            }
        }
    }
}
