STDMV = {}

function STDMV.Open()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('st-core:server:dmvOpen')
end

RegisterNetEvent('st-core:client:openDMV', function()
    STDMV.Open()
end)

RegisterCommand('dmv', function()
    STDMV.Open()
end, false)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb({ ok = true })
end)

RegisterNUICallback('load', function(_, cb)
    TriggerServerEvent('st-core:server:dmvData')
    cb({ ok = true })
end)

RegisterNUICallback('registerVehicle', function(data, cb)
    TriggerServerEvent('st-core:server:registerVehicle', data)
    cb({ ok = true })
end)

RegisterNUICallback('renewRegistration', function(data, cb)
    TriggerServerEvent('st-core:server:renewRegistration', data)
    cb({ ok = true })
end)

RegisterNUICallback('buyInsurance', function(data, cb)
    TriggerServerEvent('st-core:server:buyInsurance', data)
    cb({ ok = true })
end)

RegisterNUICallback('renewInsurance', function(data, cb)
    TriggerServerEvent('st-core:server:renewInsurance', data)
    cb({ ok = true })
end)

RegisterNUICallback('customPlate', function(data, cb)
    TriggerServerEvent('st-core:server:customPlate', data)
    cb({ ok = true })
end)

RegisterNetEvent('st-core:client:dmvData', function(data)
    SendNUIMessage({ action = 'data', data = data })
end)

RegisterNetEvent('st-core:client:dmvResult', function(result)
    SendNUIMessage({ action = 'result', result = result })
end)
