-- JG Dealerships v2 client purchase bridge.
-- JG exposes this event after a successful purchase.

RegisterNetEvent('jg-dealerships:client:purchase-vehicle:config', function(vehicle, plate, purchaseType, amount, paymentMethod, financed)
    if not Config.Integrations.JGDealershipsV2.Enabled then return end
    if GetResourceState(Config.Integrations.JGDealershipsV2.ResourceName or 'jg-dealerships') ~= 'started' then return end

    local model = nil
    local displayName = nil
    if vehicle and DoesEntityExist(vehicle) then
        model = GetEntityModel(vehicle)
        local modelName = GetDisplayNameFromVehicleModel(model)
        if modelName and modelName ~= 'CARNOTFOUND' then displayName = GetLabelText(modelName) end
    end

    TriggerServerEvent('st-core:server:jgDealershipsPurchase', {
        plate = plate,
        model = model,
        displayName = displayName,
        purchaseType = purchaseType,
        amount = amount,
        paymentMethod = paymentMethod,
        financed = financed == true,
    })
end)
