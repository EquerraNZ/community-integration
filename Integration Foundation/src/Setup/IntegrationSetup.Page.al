// The setup card. The administrator picks which error classifier is active (the
// swap point: select a value a consuming app registered to use a smarter
// classifier) and tunes the retry and stale-lock defaults.
page 73298452 "Integration Setup"
{
    PageType = Card;
    SourceTable = "Integration Setup";
    Caption = 'Integration Setup';
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Classification)
            {
                Caption = 'Error Classification';

                field("Active Error Classifier"; Rec."Active Error Classifier")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which error classifier runs on failed messages. Select a classifier a consuming app has registered to replace the default rule-based one, for example an AI-based classifier.';
                }
            }
            group(Processing)
            {
                Caption = 'Processing';

                field("Default Retry Limit"; Rec."Default Retry Limit")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many automatic attempts a transient failure gets before it waits for manual recovery.';
                }
                field("Stale Lock (Minutes)"; Rec."Stale Lock (Minutes)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how long a message may stay In Progress before stale-lock recovery may reset it.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;
}
