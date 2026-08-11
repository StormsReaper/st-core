Config = {}

Config.Debug = true
Config.ResourceName = 'st-core'
Config.Version = '0.3.0'

Config.PrintStartupMessage = true

Config.Registration = {
    DurationDays = 30,
}

Config.Plate = {
    GenerationAttempts = 50,
    CustomMaxLength = 8,
    CustomPlateFee = 5000,
}

Config.Insurance = {
    PolicyDurationDays = 30,
    PolicyGenerationAttempts = 50,
    PolicyPrefix = 'STI',
    GracePeriodDays = 0,
    RequireInsurance = true,
    CompanyName = 'Statewide Insurance',
}

Config.Payment = {
    AccountPriority = { 'bank', 'cash' },
    RegistrationFee = 250,
    RegistrationRenewalFee = 150,
    DefaultReason = 'st-core vehicle services',
}

Config.Documents = {
    InsuranceCardItem = 'insurance_card',
}

Config.DMV = {
    Command = 'dmv',
    Locations = {
        { x = 240.0, y = -1379.0, z = 33.7 },
    },
}
