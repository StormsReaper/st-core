STDMV = {}

function STDMV.Open()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('st-core:server:dmvOpen')
end

RegisterNetEvent('st-core:client:openDMV', function() STDMV.Open() end)
RegisterCommand(Config.DMV.Command or 'dmv', function() STDMV.Open() end, false)

-- JG Dealerships v2 purchase hook.
-- JG's documented purchase callback supplies vehicle, plate, purchaseType, amount, paymentMethod and financed.
-- We only forward the plate/model as a lookup hint; ownership and the authoritative vehicle record are resolved server-side.
if Config.Integrations and Config.Integrations.JGDealershipsV2 and Config.Integrations.JGDealershipsV2.Enabled then
    RegisterNetEvent(Config.Integrations.JGDealershipsV2.PurchaseEvent, function(vehicle, plate, purchaseType, amount, paymentMethod, financed)
        local model
        if vehicle and DoesEntityExist(vehicle) then
            local modelHash = GetEntityModel(vehicle)
            model = GetDisplayNameFromVehicleModel(modelHash)
            if model == 'CARNOTFOUND' then model = tostring(modelHash) end
        end

        TriggerServerEvent('st-core:server:jgDealershipsPurchase', {
            plate = plate,
            model = model,
            purchaseType = purchaseType,
            amount = tonumber(amount),
            paymentMethod = paymentMethod,
            financed = financed == true
        })
    end)
end

CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        for _, location in ipairs(Config.DMV.Locations or {}) do
            local distance = #(coords - vector3(location.x, location.y, location.z))
            if distance < 20.0 then
                wait = 0
                DrawMarker(2, location.x, location.y, location.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 60, 150, 255, 180, false, true, 2, nil, nil, false)
                if distance < 2.0 then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to open the DMV')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then STDMV.Open() end
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb({ ok = true })
end)

RegisterNUICallback('load', function(_, cb) TriggerServerEvent('st-core:server:dmvData'); cb({ ok = true }) end)
RegisterNUICallback('registerVehicle', function(data, cb) TriggerServerEvent('st-core:server:registerVehicle', data); cb({ ok = true }) end)
RegisterNUICallback('renewRegistration', function(data, cb) TriggerServerEvent('st-core:server:renewRegistration', data); cb({ ok = true }) end)
RegisterNUICallback('buyInsurance', function(data, cb) TriggerServerEvent('st-core:server:buyInsurance', data); cb({ ok = true }) end)
RegisterNUICallback('renewInsurance', function(data, cb) TriggerServerEvent('st-core:server:renewInsurance', data); cb({ ok = true }) end)
RegisterNUICallback('customPlate', function(data, cb) TriggerServerEvent('st-core:server:customPlate', data); cb({ ok = true }) end)

RegisterNetEvent('st-core:client:dmvData', function(data) SendNUIMessage({ action = 'data', data = data }) end)
RegisterNetEvent('st-core:client:dmvResult', function(result) SendNUIMessage({ action = 'result', result = result }) end)
