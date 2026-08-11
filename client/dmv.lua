STDMV = {}
local dmvPeds = {}
local dmvBlips = {}

function STDMV.Open()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('st-core:server:dmvOpen')
end

RegisterNetEvent('st-core:client:openDMV', function() STDMV.Open() end)
RegisterCommand(Config.DMV.Command or 'dmv', function() STDMV.Open() end, false)

local function createDMVBlips()
    if not Config.DMV.Blip or not Config.DMV.Blip.Enabled then return end
    for _, blip in ipairs(dmvBlips) do RemoveBlip(blip) end
    dmvBlips = {}
    for _, location in ipairs(Config.DMV.Locations or {}) do
        local blip = AddBlipForCoord(location.x, location.y, location.z)
        SetBlipSprite(blip, Config.DMV.Blip.Sprite or 498)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.DMV.Blip.Scale or 0.8)
        SetBlipColour(blip, Config.DMV.Blip.Color or 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.DMV.Blip.Name or 'Department of Motor Vehicles')
        EndTextCommandSetBlipName(blip)
        dmvBlips[#dmvBlips + 1] = blip
    end
end

local function createDMVPeds()
    local model = joaat(Config.DMV.PedModel or 's_m_m_fiboffice_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(50) end
    for _, ped in ipairs(dmvPeds) do if DoesEntityExist(ped) then DeletePed(ped) end end
    dmvPeds = {}
    for _, location in ipairs(Config.DMV.Locations or {}) do
        local ped = CreatePed(4, model, location.x, location.y, location.z - 1.0, location.heading or 0.0, false, false)
        SetEntityAsMissionEntity(ped, true, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        TaskStartScenarioInPlace(ped, Config.DMV.PedScenario or 'WORLD_HUMAN_CLIPBOARD', 0, true)
        dmvPeds[#dmvPeds + 1] = ped
    end
    SetModelAsNoLongerNeeded(model)
end

CreateThread(function()
    Wait(1000)
    createDMVBlips()
    createDMVPeds()
    while true do
        local wait = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local interactionDistance = Config.DMV.InteractionDistance or 2.0
        for index, location in ipairs(Config.DMV.Locations or {}) do
            local distance = #(coords - vector3(location.x, location.y, location.z))
            if distance < 15.0 then
                wait = 0
                local ped = dmvPeds[index]
                if ped and DoesEntityExist(ped) and distance < interactionDistance then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to speak with the DMV clerk')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then STDMV.Open() end
                end
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(dmvPeds) do if DoesEntityExist(ped) then DeletePed(ped) end end
    for _, blip in ipairs(dmvBlips) do RemoveBlip(blip) end
    SetNuiFocus(false, false)
end)

RegisterNUICallback('close', function(_, cb) SetNuiFocus(false, false); SendNUIMessage({ action = 'close' }); cb({ ok = true }) end)
RegisterNUICallback('load', function(_, cb) TriggerServerEvent('st-core:server:dmvData'); cb({ ok = true }) end)
RegisterNUICallback('lookupVehicle', function(data, cb) TriggerServerEvent('st-core:server:lookupVehicleByPlate', data); cb({ ok = true }) end)
RegisterNUICallback('registerVehicle', function(data, cb) TriggerServerEvent('st-core:server:registerVehicle', data); cb({ ok = true }) end)
RegisterNUICallback('renewRegistration', function(data, cb) TriggerServerEvent('st-core:server:renewRegistration', data); cb({ ok = true }) end)
RegisterNUICallback('buyInsurance', function(data, cb) TriggerServerEvent('st-core:server:buyInsurance', data); cb({ ok = true }) end)
RegisterNUICallback('renewInsurance', function(data, cb) TriggerServerEvent('st-core:server:renewInsurance', data); cb({ ok = true }) end)
RegisterNUICallback('customPlate', function(data, cb) TriggerServerEvent('st-core:server:customPlate', data); cb({ ok = true }) end)
RegisterNetEvent('st-core:client:dmvData', function(data) SendNUIMessage({ action = 'data', data = data }) end)
RegisterNetEvent('st-core:client:dmvResult', function(result) SendNUIMessage({ action = 'result', result = result }) end)
