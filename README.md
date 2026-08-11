# st-core

Storms Technologies core framework for FiveM.

## DMV / vehicle registration
- Physical DMV interaction point plus `/dmv` command.
- Database-backed pending vehicle purchases.
- Standard plates formatted `AAA 000`.
- Duplicate plate protection.
- Custom plates with configurable length, character, and reserved-word validation.
- Custom plate fee.
- Registration expiration and renewal.
- Server-side ownership checks against the recorded purchase.

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

## Vehicle purchase integration
A dealership should call the server export after a successful sale:

```lua
exports['st-core']:HandleVehiclePurchase(source, {
    vehicleIdentifier = vinOrUniqueVehicleId,
    model = vehicleModel,
    displayName = vehicleLabel,
    purchasePrice = finalPrice,
    purchasedAt = os.time()
})
```

This creates a pending DMV registration record. The player then completes registration at the DMV.

A client-side event is also available:

```lua
TriggerServerEvent('st-core:server:vehiclePurchased', {
    vehicleIdentifier = vinOrUniqueVehicleId,
    model = vehicleModel,
    displayName = vehicleLabel,
    purchasePrice = finalPrice,
    purchasedAt = os.time()
})
```

For trusted dealership server code, prefer the server export because the purchase price should come from the dealership's authoritative transaction rather than a client.

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

## Requirements
- FiveM server using Lua 5.4.
- `oxmysql`.
- QBCore or ESX for the built-in payment adapter.
- `ox_inventory` for physical insurance-card documents.

Run `sql/install.sql` against the server database before starting `st-core`.

Add the resource to `server.cfg` after `oxmysql` and your framework:

```cfg
ensure oxmysql
ensure qb-core
ensure ox_inventory
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
