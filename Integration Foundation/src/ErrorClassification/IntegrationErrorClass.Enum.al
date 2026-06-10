// How a failure should be treated. Transient failures (a network blip, a receiver
// briefly down) are worth retrying; permanent failures (invalid data, a missing
// mapping) need a human and should not be retried forever. Unknown is the default
// until the classifier has run. Extensible so a smarter classifier can introduce
// finer classes (for example RateLimited, AuthExpired) without a framework change.
enum 73298442 "Integration Error Class"
{
    Extensible = true;
    Caption = 'Integration Error Class';

    value(0; Unknown)
    {
        Caption = 'Unknown';
    }
    value(1; Transient)
    {
        Caption = 'Transient';
    }
    value(2; Permanent)
    {
        Caption = 'Permanent';
    }
}
