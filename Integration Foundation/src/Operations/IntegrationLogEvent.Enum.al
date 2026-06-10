// The kinds of events recorded on a message's audit trail. Extensible so a
// consuming app can record its own domain events against a message alongside the
// framework's. The framework records the lifecycle milestones and, importantly,
// every manual recovery action, so there is a durable record of who did what to a
// stuck message and why.
enum 73298446 "Integration Log Event"
{
    Extensible = true;
    Caption = 'Integration Log Event';

    value(0; Staged)
    {
        Caption = 'Staged';
    }
    value(10; Failed)
    {
        Caption = 'Failed';
    }
    value(20; Classified)
    {
        Caption = 'Classified';
    }
    value(30; Parked)
    {
        Caption = 'Parked Awaiting Reply';
    }
    value(40; "Reply Matched")
    {
        Caption = 'Reply Matched';
    }
    value(50; Retried)
    {
        Caption = 'Retried';
    }
    value(60; Resolved)
    {
        Caption = 'Resolved';
    }
    value(70; "Resolved By Exception")
    {
        Caption = 'Resolved By Exception';
    }
    value(80; Reassigned)
    {
        Caption = 'Reassigned';
    }
}
