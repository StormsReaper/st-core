Config = {}

Config.Debug = true
Config.ResourceName = 'st-core'
Config.Version = '0.4.0'
Config.PrintStartupMessage = true

Config.Framework = {
    VehicleTable = {
        QBCore = 'player_vehicles',
        ESX = 'owned_vehicles',
    },
}

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

Config.Integrations = {
    JGDealershipsV2 = {
        Enabled = true,
        ResourceName = 'jg-dealerships',
        PurchaseEvent = 'jg-dealerships:client:purchase-vehicle:config',
        IdentifierPrefix = 'jg:',
        WaitForFrameworkVehicleMs = 5000,
    },
}

Config.DMV = {
    Command = 'dmv',
    Locations = {
        { x = 240.0, y = -1379.0, z = 33.7 },
    },
}
