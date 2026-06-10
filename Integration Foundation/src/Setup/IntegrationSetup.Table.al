// Single-instance configuration for the framework. The fields that change
// behaviour without code: which error classifier is active (the swap point), how
// many automatic retries a transient failure gets before it waits for a human, and
// how long an In Progress claim may sit before stale-lock recovery may reset it.
// Seeded by the install codeunit so a fresh install has sane defaults.
table 73298401 "Integration Setup"
{
    Caption = 'Integration Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "Active Error Classifier"; Enum "Error Classifier Type")
        {
            Caption = 'Active Error Classifier';
            DataClassification = SystemMetadata;
        }
        field(20; "Default Retry Limit"; Integer)
        {
            Caption = 'Default Retry Limit';
            DataClassification = SystemMetadata;
            InitValue = 3;
            MinValue = 0;
        }
        field(30; "Stale Lock (Minutes)"; Integer)
        {
            Caption = 'Stale Lock (Minutes)';
            DataClassification = SystemMetadata;
            InitValue = 30;
            MinValue = 1;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
