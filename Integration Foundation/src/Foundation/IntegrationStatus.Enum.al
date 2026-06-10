// The lifecycle status is the only field the background processors query, so it is
// fixed and small. The transitions the framework allows:
//   New           -> In Progress
//   In Progress   -> Resolved | Failed | Awaiting Reply
//   Awaiting Reply -> In Progress (a reply arrived) | Failed
//   Failed        -> New (manual retry) | Resolved (resolve / resolve by exception)
// Keeping this enum non-extensible keeps the state machine closed and reviewable.
enum 73298441 "Integration Status"
{
    Extensible = false;
    Caption = 'Integration Status';

    value(0; New)
    {
        Caption = 'New';
    }
    value(1; "In Progress")
    {
        Caption = 'In Progress';
    }
    value(2; "Awaiting Reply")
    {
        Caption = 'Awaiting Reply';
    }
    value(3; Failed)
    {
        Caption = 'Failed';
    }
    value(4; Resolved)
    {
        Caption = 'Resolved';
    }
}
