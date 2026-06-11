enumextension 73298417 "Despatch Message Types" extends "Integration Message Type"
{
    // Outbound message type for the despatch notification. Never dispatched (the
    // dispatcher processes inbound only), so it takes the default handler. Ordinal 40
    // is fixed.
    value(40; DespatchNotification)
    {
        Caption = 'Despatch Notification';
    }
}
