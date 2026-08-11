-- JG Dealerships v2 server purchase bridge.
-- The JG callback is client-originated metadata; ownership is always verified server-side.

local function debugPrint(message)
    if Config.Debug then
        print(('[%s][JG] %s'):format(Config.ResourceName, message))
    end
end

local function makeIdentifier(plate)
    return ('%s%s'):format(Config.Integrations.JGDealershipsV2.IdentifierPrefix or 'jg:', plate)
end

local function getJGDealership(plate)
    if GetResourceState(Config.Integrations.JGDealershipsV2.ResourceName or 'jg-dealerships') ~= 'started' then
        debugPrint('JG resource is not started; dealership name will be omitted.')
        return nil
    end

    local ok, result = pcall(function()
        return MySQL.single.await('SELECT dealership FROM dealership_sales WHERE plate = ? ORDER BY id DESC LIMIT 1', { plate })
    end)

    if not ok then
        debugPrint(('Could not read dealership_sales for plate %s: %s'):format(plate, tostring(result)))
        return nil
    end

    return result and result.dealership or nil
end

local function findOwnedVehicle(ownerIdentifier, plate, timeoutMs)
    local deadline = GetGameTimer() + timeoutMs
    local attempts = 0

    repeat
        attempts += 1
        local vehicle = STVehicles.GetOwnedVehicleByPlate(ownerIdentifier, plate)
        if vehicle then
            return vehicle, attempts
        end
        Wait(250)
    until GetGameTimer() >= deadline

    return nil, attempts
end

RegisterNetEvent('st-core:server:jgDealershipsPurchase', function(data)
    local source = source

    if not Config.Integrations.JGDealershipsV2.Enabled then
        debugPrint(('Ignoring purchase from %s because JG v2 integration is disabled.'):format(source))
        return
    end

    if type(data) ~= 'table' then
        debugPrint(('Rejected purchase from %s: callback data was not a table.'):format(source))
        return
    end

    local plate = STValidation.NormalizePlate(data.plate)
    if plate == '' or #plate > 12 then
        debugPrint(('Rejected purchase from %s: invalid JG plate [%s].'):format(source, tostring(data.plate)))
        return
    end

    local ownerIdentifier = STPayments.GetIdentifier(source)
    if not ownerIdentifier then
        debugPrint(('Rejected JG purchase for source %s: framework identifier unavailable.'):format(source))
        return
    end

    debugPrint(('Purchase callback received: source=%s owner=%s plate=%s amount=%s type=%s payment=%s financed=%s'):format(
        source,
        ownerIdentifier,
        plate,
        tostring(data.amount),
        tostring(data.purchaseType),
        tostring(data.paymentMethod),
        tostring(data.financed == true)
    ))

    local timeout = tonumber(Config.Integrations.JGDealershipsV2.WaitForFrameworkVehicleMs) or 5000
    local vehicle, attempts = findOwnedVehicle(ownerIdentifier, plate, timeout)

    if not vehicle then
        debugPrint(('ERROR: Framework vehicle was not found after %d attempts (%dms) for owner=%s plate=%s. The DMV record was NOT created.'):format(
            attempts,
            timeout,
            ownerIdentifier,
            plate
        ))
        return
    end

    debugPrint(('Framework vehicle verified after %d attempts: owner=%s plate=%s'):format(attempts, ownerIdentifier, plate))

    local model = STVehicles.GetVehicleModel(vehicle) or data.model or 'unknown'
    local displayName = data.displayName or model
    local vehicleIdentifier = makeIdentifier(plate)

    if STPurchases.GetPurchase(vehicleIdentifier) then
        debugPrint(('Duplicate purchase ignored: vehicleIdentifier=%s plate=%s owner=%s'):format(vehicleIdentifier, plate, ownerIdentifier))
        return
    end

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
        debugPrint(('SUCCESS: Pending DMV purchase created: id=%s owner=%s plate=%s model=%s price=%s'):format(
            tostring(purchaseId), ownerIdentifier, plate, tostring(model), tostring(data.amount)
        ))
    else
        debugPrint(('ERROR: Failed to create pending DMV purchase for plate=%s: %s'):format(plate, tostring(purchaseId)))
    end
end)

exports('HandleJGDealershipPurchase', function(source, data)
    if source <= 0 or type(data) ~= 'table' then return false, 'invalid_request' end
    data.ownerIdentifier = STPayments.GetIdentifier(source)
    if not data.ownerIdentifier then return false, 'framework_player_not_found' end
    data.vehicleIdentifier = data.vehicleIdentifier or makeIdentifier(STValidation.NormalizePlate(data.plate))
    return STPurchases.RecordPurchase(data)
end)
