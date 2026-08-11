-- Copy these item definitions into ox_inventory/data/items.lua.
-- st-core supplies and validates all document metadata server-side.

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
