// The Activities cue: how much work is failed, in progress, or waiting, at a glance.
// Modelled on the standard BC activity cues. Backed by the single-record cue table
// whose counts are FlowFields, so the numbers are computed once here rather than as
// columns on the message list (which would slow that list down per row).
page 73298454 "Integration Activities"
{
    PageType = CardPart;
    SourceTable = "Integration Cue";
    Caption = 'Integration Activities';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            cuegroup(Messages)
            {
                Caption = 'Integration Messages';

                field("Failed Count"; Rec."Failed Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many integration messages have failed and need attention.';
                    DrillDownPageId = "Integration Messages";
                    StyleExpr = 'Unfavorable';
                }
                field("In Progress Count"; Rec."In Progress Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many integration messages are currently being processed.';
                    DrillDownPageId = "Integration Messages";
                }
                field("Awaiting Reply Count"; Rec."Awaiting Reply Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many integration messages are parked waiting for a reply from an external system.';
                    DrillDownPageId = "Integration Messages";
                    StyleExpr = 'Ambiguous';
                }
                field("New Count"; Rec."New Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many integration messages are waiting to be picked up for processing.';
                    DrillDownPageId = "Integration Messages";
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        // The cue is a single fixed record; make sure it exists before display.
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Failed Count", "In Progress Count", "Awaiting Reply Count", "New Count");
    end;
}
