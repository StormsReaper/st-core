# st-core

Storms Technologies core framework for FiveM.

## DMV / vehicle registration
- Physical DMV interaction point plus `/dmv` command.
- Database-backed pending vehicle purchases.
- Standard plates formatted `AAA 000`.
- Standard plate generation checks both st-core registrations and the framework vehicle database for collisions.
- Custom plates with configurable length, character, and reserved-word validation.
- Custom plate fee.
- Registration expiration and renewal.
- Server-side ownership checks against the recorded purchase.
- Framework vehicle plate synchronization when a DMV plate is issued.

## JG Dealerships v2

`st-core` includes a native JG Dealerships v2 purchase integration. JG's documented `jg-dealerships:client:purchase-vehicle:config` callback is listened to by st-core; you do not need to edit the JG resource itself. urlJG Dealerships v2 documentationhttps://docs.jgscripts.com/dealerships/introduction

The integration:

1. Detects the completed JG purchase.
2. Resolves the buyer from QBCore/ESX server-side.
3. Finds the newly-created framework vehicle by its JG purchase plate.
4. Creates a pending st-core DMV purchase record.
5. Allows the player to visit the DMV.
6. Generates the final `AAA 000` plate or validates a custom plate.
7. Updates the framework vehicle database from the JG purchase plate to the DMV-issued plate.
8. Creates the active registration.

The integration is enabled by default in `config.lua` and can be disabled with `Config.Integrations.JGDealershipsV2.Enabled = false`.

## Vehicle insurance
- Monthly policies.
- Liability coverage is the minimum legal coverage.
- Liability, Standard, Comprehensive, and Premium plans are seeded by `sql/install.sql`.
- Policy numbers are generated automatically.
- Policy expiration and renewal are persisted.
- Insurance card issuance through ox_inventory.
- Registration/insurance legal-status exports for police, MDT, dealership, and garage resources.

## Payments
`st-core` automatically detects QBCore or ESX for player money operations. The configured account priority is bank, then cash. Registration, renewal, insurance, and custom-plate charges are performed server-side and failed operations are refunded when the downstream operation fails.

## Insurance card
The card is created with ox_inventory metadata containing policy number, insured vehicle, plate, coverage type, coverage limits, deductible, premium, and effective/expiration timestamps.

Add the item definition from `integrations/ox_inventory/insurance_card.lua` to your ox_inventory item definitions:

```lua
['insurance_card'] = {
    label = 'Vehicle Insurance Card',
    weight = 5,
    stack = false,
    close = true,
    description = 'Official vehicle insurance identification card.',
}
```

## Generic vehicle purchase integration
For other dealership resources, use the trusted server export after a successful sale:

```lua
exports['st-core']:HandleVehiclePurchase(source, {
    vehicleIdentifier = vinOrUniqueVehicleId,
    model = vehicleModel,
    displayName = vehicleLabel,
    purchasePrice = finalPrice,
    purchasedAt = os.time()
})
```

The `source` argument is the buyer's server ID. The core resolves the player's framework identifier server-side and creates a pending purchase.

## Requirements
- FiveM server using Lua 5.4.
- `oxmysql`.
- QBCore or ESX for the built-in payment and vehicle adapters.
- `ox_inventory` for physical insurance-card documents.
- JG Dealerships v2 is optional; its integration can be disabled.

Run `sql/install.sql` against the server database before starting `st-core`.

Recommended startup order:

```cfg
ensure oxmysql
ensure qb-core
ensure ox_inventory
ensure jg-dealerships
ensure st-core
```

## Core exports

```lua
local registration = exports['st-core']:GetVehicleRegistration(vehicleIdentifier)
local insurance = exports['st-core']:GetVehicleInsurance(vehicleIdentifier)
local legal = exports['st-core']:GetVehicleLegalStatus(vehicleIdentifier)
```

## Notes
The core keeps registration, insurance, payment, document, and purchase workflows server-authoritative. Dealerships create purchase records; the DMV controls registration; insurance is purchased only against an owned registered vehicle. The NUI is deliberately contained inside `st-core` so other resources can consume the APIs without duplicating database logic.
