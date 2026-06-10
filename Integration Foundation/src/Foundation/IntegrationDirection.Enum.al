// The direction splits inbound (data arriving from systems we do not control)
// from outbound (work we push downstream). It is fixed: every integration is one
// or the other, so this enum is deliberately not extensible.
enum 73298440 "Integration Direction"
{
    Extensible = false;
    Caption = 'Integration Direction';

    value(0; Inbound)
    {
        Caption = 'Inbound';
    }
    value(1; Outbound)
    {
        Caption = 'Outbound';
    }
}
