enumextension 73298415 "Fulfilment Message Types" extends "Integration Message Type"
{
    // Outbound message type for the fulfilment request staged as the correlation
    // parent. It is never dispatched (the dispatcher processes inbound only), so it
    // takes the default handler. Ordinal 30 is fixed.
    value(30; FulfilmentRequest)
    {
        Caption = 'Fulfilment Request';
    }
}
