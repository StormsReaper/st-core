# st-core

Storms Technologies core framework for FiveM.

## Current systems

### Vehicle registration
- Database-backed registration records.
- Standard plates formatted as `AAA 000`.
- Duplicate plate protection.
- Configurable custom plate validation.
- Registration expiration and renewal.
- Registration/legal-status exports for police, MDT, dealership, and garage resources.

### Vehicle insurance
- Monthly policies.
- Liability coverage is the minimum legal coverage.
- Liability, Standard, Comprehensive, and Premium plans are seeded by `sql/install.sql`.
- Policy numbers are generated automatically.
- Policy expiration and renewal are persisted.
- Cancellation state and reason are persisted.
- Insurance/legal-status exports are available to other resources.

## Requirements

- FiveM server using Lua 5.4.
- `oxmysql`.

Run `sql/install.sql` against the server database before starting `st-core`.

## Installation

Add the resource to `server.cfg` after `oxmysql`:

```cfg
ensure oxmysql
ensure st-core
```

## Export examples

```lua
local registration = exports['st-core']:GetVehicleRegistration(vehicleIdentifier)
local insurance = exports['st-core']:GetVehicleInsurance(vehicleIdentifier)
local legal = exports['st-core']:GetVehicleLegalStatus(vehicleIdentifier)
```

Register a vehicle:

```lua
local success, result = exports['st-core']:RegisterVehicle({
    ownerIdentifier = playerIdentifier,
    vehicleIdentifier = vehicleIdentifier
})
```

Register with a custom plate:

```lua
local success, result = exports['st-core']:RegisterVehicle({
    ownerIdentifier = playerIdentifier,
    vehicleIdentifier = vehicleIdentifier,
    plate = 'STORMS 1'
})
```

Purchase insurance:

```lua
local success, policy = exports['st-core']:PurchaseVehicleInsurance({
    ownerIdentifier = playerIdentifier,
    vehicleIdentifier = vehicleIdentifier,
    planId = 'liability'
})
```

## Framework integration

The current core intentionally does not hard-code QBCore or ESX player/economy APIs. Ownership verification, money removal, inventory documents, DMV locations, and NUI are planned adapter/integration layers.

The server-side registration and insurance APIs should be treated as the source of truth. Future DMV, dealership, police/MDT, banking, and document resources can consume these exports without duplicating database logic.
