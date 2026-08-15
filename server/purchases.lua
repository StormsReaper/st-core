STPurchases = {}

local function dbCall(callback)
    local ok, result = pcall(callback)
    if not ok then
        if Config.Debug then
            print(('[%s] WARNING: st_vehicle_purchases query failed: %s'):format(Config.ResourceName, tostring(result)))
        end
        return nil, false
    end
    return result, true
end

local function getPending(source)
    local identifier = STPayments.GetIdentifier(source)
    if not identifier then return {} end

    local rows, ok = dbCall(function()
        return MySQL.query.await([[SELECT * FROM st_vehicle_purchases WHERE owner_identifier = ? AND status = 'pending' ORDER BY purchased_at DESC]], { identifier })
    end)

    return ok and (rows or {}) or {}
end

function STPurchases.RecordPurchase(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    if not STValidation.IsIdentifier(data.ownerIdentifier) then return false, 'invalid_owner_identifier' end
    if not STValidation.IsIdentifier(data.vehicleIdentifier) then return false, 'invalid_vehicle_identifier' end

    local existing, existingOk = dbCall(function()
        return MySQL.single.await('SELECT id FROM st_vehicle_purchases WHERE vehicle_identifier = ? LIMIT 1', { data.vehicleIdentifier })
    end)
    if not existingOk then return false, 'purchase_database_unavailable' end
    if existing then return false, 'purchase_already_recorded' end

    local id, insertOk = dbCall(function()
        return MySQL.insert.await([[
            INSERT INTO st_vehicle_purchases
                (owner_identifier, vehicle_identifier, temporary_plate, model, display_name, purchase_price, purchase_type, payment_method, financed, dealership, purchased_at, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
        ]], {
            data.ownerIdentifier,
            data.vehicleIdentifier,
            data.temporaryPlate,
            data.model or 'unknown',
            data.displayName or data.model or 'Vehicle',
            tonumber(data.purchasePrice) or 0,
            data.purchaseType,
            data.paymentMethod,
            data.financed and 1 or 0,
            data.dealership,
            tonumber(data.purchasedAt) or os.time(),
        })
    end)

    return insertOk and id ~= nil, insertOk and (id or 'database_insert_failed') or 'database_insert_failed'
end

function STPurchases.GetPending(source)
    return getPending(source)
end

function STPurchases.GetPurchase(vehicleIdentifier)
    if not STValidation.IsIdentifier(vehicleIdentifier) then return nil end
    local result, ok = dbCall(function()
        return MySQL.single.await('SELECT * FROM st_vehicle_purchases WHERE vehicle_identifier = ? LIMIT 1', { vehicleIdentifier })
    end)
    return ok and result or nil
end

function STPurchases.MarkRegistered(vehicleIdentifier)
    if not STValidation.IsIdentifier(vehicleIdentifier) then return false end
    local result, ok = dbCall(function()
        return MySQL.update.await(
            "UPDATE st_vehicle_purchases SET status = 'registered', registered_at = ?, updated_at = CURRENT_TIMESTAMP WHERE vehicle_identifier = ? AND status = 'pending'",
            { os.time(), vehicleIdentifier }
        )
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
exports('MarkVehiclePurchaseRegistered', STPurchases.MarkRegistered)
