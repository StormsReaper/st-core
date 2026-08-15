Config = {}

Config.Debug = true
Config.ResourceName = 'st-core'
Config.Version = '0.5.1'
Config.PrintStartupMessage = true

Config.Framework = {
    VehicleTable = {
        QBCore = 'player_vehicles',
        ESX = 'owned_vehicles',
    },
}

Config.Registration = {
    DurationDays = 30,
    TransferFee = 350,
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
    VehicleSaleContractItem = 'vehicle_sale_contract',
    ContractValidityDays = 7,
    ContractMaxDistance = 5.0,
}

Config.Sales = {
    RequireVehicleNearSeller = true,
    RequireBuyerNearSeller = true,
    BuyerDistance = 5.0,
    VehicleDistance = 8.0,
    RequireSameVehicleAtFinalization = true,
    AutoCancelExpiredContracts = true,
}

-- JG is an optional purchase-recording integration. DMV registration never depends on it.
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
    InteractionDistance = 2.0,
    PedModel = 's_m_m_fiboffice_01',
    PedScenario = 'WORLD_HUMAN_CLIPBOARD',
    Blip = {
        Enabled = true,
        Sprite = 498,
        Color = 3,
        Scale = 0.8,
        Name = 'Department of Motor Vehicles',
    },
    Locations = {
        { x = 415.1775, y = -1108.178, z = 31.02456, heading = 0.0 },
    },
}
