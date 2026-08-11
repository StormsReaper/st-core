# Vehicle purchase integrations

## JG Dealerships v2

`st-core` has a built-in JG Dealerships v2 integration. No edits to the escrowed `jg-dealerships` resource are required.

JG documents the client purchase callback as:

```lua
RegisterNetEvent("jg-dealerships:client:purchase-vehicle:config", function(vehicle, plate, purchaseType, amount, paymentMethod, financed)
    -- custom post-purchase code
end)
```

The `st-core` client listens to that event and forwards the plate to its server-side integration. The server then resolves the buyer from the active framework player and looks up the newly-created framework vehicle record by plate. This avoids trusting the client for ownership.

The JG purchase plate becomes a temporary vehicle identifier (`jg:<original plate>`) inside `st-core`. When the player completes registration at the DMV, st-core generates the final state plate in `AAA 000` format (or validates the requested custom plate), then updates the framework vehicle record to the new plate.

This means the normal flow is:

1. Player buys vehicle through JG Dealerships v2.
2. JG creates the owned vehicle and fires its purchase callback.
3. st-core detects the completed purchase and creates a `pending` DMV purchase record.
4. Player visits the DMV.
5. st-core charges the registration fee.
6. st-core generates `AAA 000` or validates a custom plate.
7. st-core updates the framework vehicle's plate.
8. st-core creates the active registration record.
9. The vehicle becomes eligible for insurance.

### JG configuration

The integration is enabled by default in `config.lua`:

```lua
Config.Integrations.JGDealershipsV2 = {
    Enabled = true,
    ResourceName = 'jg-dealerships',
    PurchaseEvent = 'jg-dealerships:client:purchase-vehicle:config',
    IdentifierPrefix = 'jg:',
    WaitForFrameworkVehicleMs = 5000,
}
```

The documented JG purchase callback and v2 purchase flow are provided by JG Scripts. urlJG Dealerships v2 documentationhttps://docs.jgscripts.com/dealerships/introduction

## Generic server-side dealership API

For other dealership resources, call the trusted server export after a successful sale:

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
