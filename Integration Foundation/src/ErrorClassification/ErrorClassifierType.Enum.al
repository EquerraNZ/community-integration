// Selects which error classifier is active. Like the integration type, this is an
// extensible enum that "implements" its interface, so swapping the classifier is a
// configuration choice: a consuming app adds a value bound to its own
// IErrorClassifier codeunit and selects it on the Integration Setup card. The
// classifier job resolves the active implementation from this enum and never names
// a concrete codeunit, which is what keeps the classifier swappable without
// touching any caller.
enum 73298445 "Error Classifier Type" implements IErrorClassifier
{
    Extensible = true;
    Caption = 'Error Classifier Type';
    DefaultImplementation = IErrorClassifier = "Default Error Classifier";

    value(0; Default)
    {
        Caption = 'Default (rule-based)';
        Implementation = IErrorClassifier = "Default Error Classifier";
    }
}
