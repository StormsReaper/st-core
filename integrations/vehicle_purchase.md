# Vehicle purchase integration

`st-core` intentionally does not assume which dealership resource creates the vehicle. The dealership should call the purchase API immediately after a successful vehicle sale.

## Server export

```lua
exports['st-core']:HandleVehiclePurchase(source, {
    vehicleIdentifier = vinOrUniqueVehicleId,
    model = vehicleModel,
    displayName = vehicleLabel,
    purchasePrice = finalPrice,
    purchasedAt = os.time()
})
```

The `source` argument is the buyer's server ID. The core resolves the player's framework identifier through QBCore or ESX and creates a `pending` purchase. The player can then visit the DMV and register the vehicle.

## Network event

The same workflow is available to dealership resources through:

```lua
TriggerServerEvent('st-core:server:vehiclePurchased', {
    vehicleIdentifier = vinOrUniqueVehicleId,
    model = vehicleModel,
    displayName = vehicleLabel,
    purchasePrice = finalPrice,
    purchasedAt = os.time()
})
```

For server-side dealership scripts, prefer the export because it avoids trusting a client-supplied purchase price.
