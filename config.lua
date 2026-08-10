Config = {}

Config.Debug = true
Config.ResourceName = 'st-core'
Config.Version = '0.2.0'

Config.PrintStartupMessage = true

-- Database-backed vehicle registration settings.
Config.Registration = {
    DurationDays = 30,
}

-- Plate generation and custom plate rules.
Config.Plate = {
    GenerationAttempts = 50,
    CustomMaxLength = 8,
    CustomPlateFee = 5000,
}

-- Insurance policy settings. Policies renew on a monthly cycle.
Config.Insurance = {
    PolicyDurationDays = 30,
    PolicyGenerationAttempts = 50,
    PolicyPrefix = 'STI',
    GracePeriodDays = 0,
    RequireInsurance = true,
}
