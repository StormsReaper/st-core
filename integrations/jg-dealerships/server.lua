-- JG Dealerships v2 server purchase bridge.
-- The client callback only supplies purchase metadata; ownership is verified against the framework DB.

local function debugPrint(message)
    if Config.Debug then print(('[%s][JG] %s'):format(Config.ResourceName, message)) end
end

local function makeIdentifier(plate)
    return ('%s%s'):format(Config.Integrations.JGDealershipsV2.IdentifierPrefix or 'jg:', plate)
end

local function getJGDealership(plate)
    if GetResourceState(Config.Integrations.JGDealershipsV2.ResourceName or 'jg-dealerships') ~= 'started' then return nil end
    local ok, result = pcall(function()
        return MySQL.single.await('SELECT dealership FROM dealership_sales WHERE plate = ? ORDER BY id DESC LIMIT 1', { plate })
    end)
    return ok and result and result.dealership or nil
end

RegisterNetEvent('st-core:server:jgDealershipsPurchase', function(data)
    local source = source
    if not Config.Integrations.JGDealershipsV2.Enabled or type(data) ~= 'table' then return end

    local plate = STValidation.NormalizePlate(data.plate)
    if plate == '' or #plate > 12 then return end
    local ownerIdentifier = STPayments.GetIdentifier(source)
    if not ownerIdentifier then return end

    local vehicle
    local timeout = tonumber(Config.Integrations.JGDealershipsV2.WaitForFrameworkVehicleMs) or 5000
    local deadline = GetGameTimer() + timeout
    repeat
        vehicle = STVehicles.GetOwnedVehicleByPlate(ownerIdentifier, plate)
        if vehicle then break end
        Wait(100)
    until GetGameTimer() >= deadline

    if not vehicle then
        debugPrint(('Could not verify framework ownership for JG purchase plate %s'):format(plate))
        return
    end

    local model = STVehicles.GetVehicleModel(vehicle) or data.model or 'unknown'
    local displayName = data.displayName or model
    local vehicleIdentifier = makeIdentifier(plate)
    if STPurchases.GetPurchase(vehicleIdentifier) then return end

    local ok, purchaseId = STPurchases.RecordPurchase({
        ownerIdentifier = ownerIdentifier,
        vehicleIdentifier = vehicleIdentifier,
        temporaryPlate = plate,
        model = model,
        displayName = displayName,
        purchasePrice = tonumber(data.amount) or 0,
        purchaseType = data.purchaseType,
        paymentMethod = data.paymentMethod,
        financed = data.financed == true,
        dealership = getJGDealership(plate),
        purchasedAt = os.time(),
    })

    if ok then
        debugPrint(('Tracked JG v2 purchase: owner=%s plate=%s id=%s'):format(ownerIdentifier, plate, tostring(purchaseId)))
    elseif Config.Debug then
        print(('[%s][JG] Failed to track purchase %s: %s'):format(Config.ResourceName, plate, tostring(purchaseId)))
    end
end)

exports('HandleJGDealershipPurchase', function(source, data)
    if source <= 0 or type(data) ~= 'table' then return false, 'invalid_request' end
    data.ownerIdentifier = STPayments.GetIdentifier(source)
    if not data.ownerIdentifier then return false, 'framework_player_not_found' end
    data.vehicleIdentifier = data.vehicleIdentifier or makeIdentifier(STValidation.NormalizePlate(data.plate))
    return STPurchases.RecordPurchase(data)
end)
