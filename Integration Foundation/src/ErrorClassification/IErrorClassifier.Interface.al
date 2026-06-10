// The swappable error classifier contract. Classification runs out of band (a
// separate Job Queue pass), never inline at failure time, so the failing
// transaction stays small and the choice of classifier is a configuration decision
// rather than a code dependency for callers. The default implementation is plain
// rule-based matching; a consuming app can register a smarter one (for example an
// AI-based classifier) by adding an "Error Classifier Type" value bound to its
// codeunit and selecting it in setup. No caller or framework object changes.
interface IErrorClassifier
{
    /// <summary>
    /// Inspect a failed message (its captured error text, type, retry count) and
    /// return the class the failure should be treated as. Must not modify the
    /// message or perform side effects; it only decides a class.
    /// </summary>
    /// <param name="IntegrationMessage">The failed message to classify.</param>
    /// <returns>The error class to record.</returns>
    procedure Classify(var IntegrationMessage: Record "Integration Message"): Enum "Integration Error Class"
}
