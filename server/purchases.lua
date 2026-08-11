STPurchases = {}

local function getPending(source)
    local identifier = STPayments.GetIdentifier(source)
    if not identifier then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await([[SELECT * FROM st_vehicle_purchases WHERE owner_identifier = ? AND status = 'pending' ORDER BY purchased_at DESC]], { identifier })
    end)
    if not ok then
        if Config.Debug then print(('[%s] WARNING: st_vehicle_purchases is unavailable. Pending purchase list skipped; plate-based DMV lookup can still be used.'):format(Config.ResourceName)) end
        return {}
    end
    return rows or {}
end

function STPurchases.RecordPurchase(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    if not STValidation.IsIdentifier(data.ownerIdentifier) then return false, 'invalid_owner_identifier' end
    if not STValidation.IsIdentifier(data.vehicleIdentifier) then return false, 'invalid_vehicle_identifier' end
    local existing = MySQL.single.await('SELECT id FROM st_vehicle_purchases WHERE vehicle_identifier = ? LIMIT 1', { data.vehicleIdentifier })
    if existing then return false, 'purchase_already_recorded' end

    local id = MySQL.insert.await([[
        INSERT INTO st_vehicle_purchases
            (owner_identifier, vehicle_identifier, temporary_plate, model, display_name, purchase_price, purchase_type, payment_method, financed, dealership, purchased_at, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    ]], {
        data.ownerIdentifier, data.vehicleIdentifier, data.temporaryPlate, data.model or 'unknown', data.displayName or data.model or 'Vehicle',
        tonumber(data.purchasePrice) or 0, data.purchaseType, data.paymentMethod, data.financed and 1 or 0, data.dealership, tonumber(data.purchasedAt) or os.time()
    })
    return id ~= nil, id or 'database_insert_failed'
end

function STPurchases.GetPending(source) return getPending(source) end
function STPurchases.GetPurchase(vehicleIdentifier)
    if not STValidation.IsIdentifier(vehicleIdentifier) then return nil end
    local ok, result = pcall(function()
        return MySQL.single.await('SELECT * FROM st_vehicle_purchases WHERE vehicle_identifier = ? LIMIT 1', { vehicleIdentifier })
    end)
    return ok and result or nil
end
function STPurchases.MarkRegistered(vehicleIdentifier)
    local ok, result = pcall(function()
        return MySQL.update.await("UPDATE st_vehicle_purchases SET status = 'registered', registered_at = ?, updated_at = CURRENT_TIMESTAMP WHERE vehicle_identifier = ? AND status = 'pending'", { os.time(), vehicleIdentifier })
    end)
    return ok and result == 1 or false
end
function STPurchases.HandlePurchase(source, data)
    if source <= 0 or type(data) ~= 'table' then return false, 'invalid_request' end
    data.ownerIdentifier = STPayments.GetIdentifier(source)
    if not data.ownerIdentifier then return false, 'framework_player_not_found' end
    return STPurchases.RecordPurchase(data)
end
exports('RecordVehiclePurchase', STPurchases.RecordPurchase)
exports('HandleVehiclePurchase', STPurchases.HandlePurchase)
exports('GetPendingVehiclePurchases', STPurchases.GetPending)
exports('GetVehiclePurchase', STPurchases.GetPurchase)
