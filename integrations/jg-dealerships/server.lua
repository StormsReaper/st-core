-- JG Dealerships v2 integration for st-core.
-- JG exposes the client purchase event `jg-dealerships:client:purchase-vehicle:config`.
-- st-core listens to that event without requiring edits to the JG resource.

local function debugPrint(message)
    if Config.Debug then
        print(('[%s][JG] %s'):format(Config.ResourceName, message))
    end
end

local function makeIdentifier(plate)
    return ('%s%s'):format(Config.Integrations.JGDealershipsV2.IdentifierPrefix or 'jg:', plate)
end

RegisterNetEvent('st-core:server:jgDealershipsPurchase', function(data)
    local source = source
    if not Config.Integrations.JGDealershipsV2.Enabled then return end
    if type(data) ~= 'table' then return end

    local plate = STValidation.NormalizePlate(data.plate)
    if plate == '' or #plate > 12 then return end

    local ownerIdentifier = STPayments.GetIdentifier(source)
    if not ownerIdentifier then return end

    -- JG fires its purchase callback as part of the completed purchase flow.
    -- Give the framework vehicle insert a short window to become queryable.
    local vehicle
    local timeout = tonumber(Config.Integrations.JGDealershipsV2.WaitForFrameworkVehicleMs) or 5000
    local deadline = GetGameTimer() + timeout
    repeat
        vehicle = STVehicles.GetOwnedVehicleByPlate(ownerIdentifier, plate)
        if vehicle then break end
        Wait(100)
    until GetGameTimer() >= deadline

    local model = vehicle and STVehicles.GetVehicleModel(vehicle) or data.model
    if not model or model == '' then model = 'unknown' end

    local vehicleIdentifier = makeIdentifier(plate)
    local existing = STPurchases.GetPurchase(vehicleIdentifier)
    if existing then
        if existing.owner_identifier == ownerIdentifier then
            debugPrint(('Purchase already tracked for %s'):format(plate))
        end
        return
    end

    -- The amount from the client event is retained only as purchase metadata.
    -- st-core never trusts this value for payment authorization.
    local price = tonumber(data.amount) or 0
    local ok, purchaseId = STPurchases.RecordPurchase({
        ownerIdentifier = ownerIdentifier,
        vehicleIdentifier = vehicleIdentifier,
        model = model,
        displayName = data.displayName or model,
        purchasePrice = price,
        purchasedAt = os.time(),
    })

    if ok then
        debugPrint(('Tracked JG purchase: owner=%s plate=%s id=%s'):format(ownerIdentifier, plate, tostring(purchaseId)))
    elseif Config.Debug then
        print(('[%s][JG] Failed to track purchase %s: %s'):format(Config.ResourceName, plate, tostring(purchaseId)))
    end
end)

exports('HandleJGDealershipPurchase', function(source, data)
    if source <= 0 then return false, 'invalid_source' end
    if type(data) ~= 'table' then return false, 'invalid_data' end
    data.ownerIdentifier = STPayments.GetIdentifier(source)
    if not data.ownerIdentifier then return false, 'framework_player_not_found' end
    data.vehicleIdentifier = data.vehicleIdentifier or makeIdentifier(STValidation.NormalizePlate(data.plate))
    return STPurchases.RecordPurchase(data)
end)
