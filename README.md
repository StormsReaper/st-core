# st-core

Storms Technologies core framework for FiveM.

## DMV / vehicle registration
- Physical DMV interaction point plus `/dmv` command.
- Database-backed pending vehicle purchases.
- Standard plates formatted `AAA 000` with collision checking.
- Custom plates with validation and configurable fee.
- VIN generation and permanent vehicle registry records.
- Owner name, vehicle, purchase, dealership, financing and registration data are persisted.
- Registration renewal.
- Server-side ownership checks.

## DMV purchase screen
The DMV shows pending JG/dealership purchases with temporary plate, vehicle/model, purchase price, purchase type, payment method, financing state, dealership and purchase date. Once registered, the official record displays VIN, plate, owner name, registration expiry and purchase/dealership data.

## Insurance
- Liability coverage is the minimum legal coverage.
- Liability, Standard, Comprehensive, and Premium plans are seeded by `sql/install.sql`.
- Monthly policy expiration and renewal.
- Policy numbers are generated automatically.
- Insurance card item for ox_inventory containing policy and coverage metadata.
- Registration/insurance legal-status exports for police, MDT, dealership, and garage resources.

## JG Dealerships v2
The integration uses JG's documented `jg-dealerships:client:purchase-vehicle:config` callback. JG passes `vehicle`, `plate`, `purchaseType`, `amount`, `paymentMethod`, and `financed`; st-core sends the purchase metadata to the server, then verifies ownership against the QBCore/ESX vehicle database before creating the pending DMV record. This avoids modifying the escrowed JG resource.

JG's current documentation also demonstrates this callback as the supported post-purchase integration point. See the official JG documentation: https://docs.jgscripts.com/dealerships/integrations/pickle-mods-documents

## Vehicle registry / MDT
`st_vehicle_records` is a normalized MDT-ready registry containing:
- VIN
- plate
- current owner identifier and character name
- vehicle model/display name
- purchase price
- dealership
- registration status/expiration
- insurance policy/status/expiration

The framework vehicle record is also updated during registration and private transfer, so MDTS that read the normal QBCore `player_vehicles` or ESX `owned_vehicles` tables continue to resolve the current owner and plate. MDTS that need VIN/DMV-specific fields can use:

```lua
exports['st-core']:GetVehicleRecordByPlate(plate)
exports['st-core']:GetVehicleRecordByVIN(vin)
```

There is no universal FiveM MDT schema, so the normalized registry is intentionally exposed instead of assuming one MDT vendor's private database tables.

## Private vehicle sale contracts
The DMV now supports an end-to-end private sale workflow:

1. Seller visits the DMV and requests a `vehicle_sale_contract` document.
2. Seller stands beside their registered vehicle with the buyer nearby.
3. Seller uses the contract from ox_inventory.
4. st-core identifies the closest vehicle, verifies that it belongs to the seller, captures VIN/plate/model/owner information and identifies the closest buyer.
5. Seller enters the sale price and signs on the document.
6. Seller gives the signed contract to the buyer using ox_inventory's normal item transfer.
7. Buyer uses the document. The server verifies that the buyer is the named buyer and records the buyer signature.
8. Buyer takes the signed contract to the DMV and submits it.
9. The DMV re-validates the seller's current ownership, contract status and buyer identity, charges the configurable transfer fee, updates the framework owner, creates the buyer's new DMV registration period and updates the MDT registry.
10. The seller's active insurance policy is cancelled because the vehicle changed owners. The buyer can then purchase their own policy.

A buyer signature alone **never transfers ownership**. Pressing Enter or otherwise attempting to submit an unsigned buyer document does nothing because the server requires a valid signature before the contract can reach `buyer_signed`. The final transfer requires the signed document to be physically submitted at the DMV.

Contracts expire automatically and every issuance/signature/transfer is written to `st_dmv_document_audit`. Completed ownership changes are also written to `st_vehicle_transfer_audit`.

## Documents / ox_inventory
Copy the definitions in `integrations/ox_inventory/insurance_card.lua` into `ox_inventory/data/items.lua`:

```lua
['insurance_card'] = {
    label = 'Vehicle Insurance Card',
    weight = 5,
    stack = false,
    consume = 0,
    close = true,
    description = 'Official vehicle insurance identification card.',
},

['vehicle_sale_contract'] = {
    label = 'Vehicle Sale Contract',
    weight = 10,
    stack = false,
    consume = 0,
    close = true,
    description = 'Official DMV vehicle bill of sale.',
    client = {
        export = 'st-core.useVehicleSaleContract',
    },
},
```

The contract uses ox_inventory's supported client item export mechanism and preserves a server-generated contract ID in metadata. The contract ID is validated against the database on every use.

## Vehicle purchase API
For non-JG dealerships, a trusted server-side dealership can call:

```lua
exports['st-core']:HandleVehiclePurchase(source, {
    vehicleIdentifier = vinOrUniqueVehicleId,
    model = vehicleModel,
    displayName = vehicleLabel,
    purchasePrice = finalPrice,
    purchaseType = 'cash',
    paymentMethod = 'bank',
    financed = false,
    dealership = 'Stormline Auto Sales',
    purchasedAt = os.time()
})
```

For JG v2, use the built-in integration instead of editing JG.

## Requirements
- FiveM Lua 5.4.
- `oxmysql`.
- QBCore or ESX for built-in framework payments/ownership updates.
- `ox_inventory` for insurance cards and sale contracts.
- JG Dealerships v2 is optional; the integration is enabled by default and safely does nothing when JG is not running.

Run `sql/install.sql` against the server database, then run the migrations in `sql/migrations/` in order. Add the resource after `oxmysql`, your framework, and `ox_inventory`:

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
local vehicleByPlate = exports['st-core']:GetVehicleRecordByPlate(plate)
local vehicleByVIN = exports['st-core']:GetVehicleRecordByVIN(vin)
```

## Security model
All authoritative operations happen server-side: payment, purchase ownership verification, plate allocation, VIN allocation, contract identity, signature acceptance, framework ownership changes, registration issuance, and insurance eligibility. Client UI values are treated as requests rather than proof of ownership or payment.
