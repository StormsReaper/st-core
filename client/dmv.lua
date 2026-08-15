STDMV = {}
local dmvPeds, dmvBlips = {}, {}

function STDMV.Open() SetNuiFocus(true, true); SendNUIMessage({ action = 'open' }) end
function STDMV.OpenInsuranceClaim() SetNuiFocus(true, true); SendNUIMessage({ action = 'openClaim' }) end
RegisterNetEvent('st-core:client:openDMV', function() STDMV.Open() end)
RegisterCommand(Config.DMV.Command or 'dmv', function() STDMV.Open() end, false)
RegisterCommand('insclaim', function() STDMV.OpenInsuranceClaim() end, false)

local function createDMVBlips()
    if not Config.DMV.Blip or not Config.DMV.Blip.Enabled then return end
    for _, blip in ipairs(dmvBlips) do RemoveBlip(blip) end; dmvBlips = {}
    for _, location in ipairs(Config.DMV.Locations or {}) do
        local blip = AddBlipForCoord(location.x, location.y, location.z)
        SetBlipSprite(blip, Config.DMV.Blip.Sprite or 498); SetBlipDisplay(blip, 4); SetBlipScale(blip, Config.DMV.Blip.Scale or 0.8); SetBlipColour(blip, Config.DMV.Blip.Color or 3); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.DMV.Blip.Name or 'Department of Motor Vehicles'); EndTextCommandSetBlipName(blip); dmvBlips[#dmvBlips + 1] = blip
    end
end
local function createDMVPeds()
    local model = joaat(Config.DMV.PedModel or 's_m_m_fiboffice_01'); RequestModel(model); while not HasModelLoaded(model) do Wait(50) end
    for _, ped in ipairs(dmvPeds) do if DoesEntityExist(ped) then DeletePed(ped) end end; dmvPeds = {}
    for _, location in ipairs(Config.DMV.Locations or {}) do
        local ped = CreatePed(4, model, location.x, location.y, location.z - 1.0, location.heading or 0.0, false, false); SetEntityAsMissionEntity(ped, true, true); SetEntityInvincible(ped, true); FreezeEntityPosition(ped, true); SetBlockingOfNonTemporaryEvents(ped, true); SetPedCanRagdoll(ped, false); TaskStartScenarioInPlace(ped, Config.DMV.PedScenario or 'WORLD_HUMAN_CLIPBOARD', 0, true); dmvPeds[#dmvPeds + 1] = ped
    end; SetModelAsNoLongerNeeded(model)
end
CreateThread(function()
    Wait(1000); createDMVBlips(); createDMVPeds()
    while true do
        local wait, coords = 1000, GetEntityCoords(PlayerPedId()); local distanceLimit = Config.DMV.InteractionDistance or 2.0
        for index, location in ipairs(Config.DMV.Locations or {}) do
            local distance = #(coords - vector3(location.x, location.y, location.z))
            if distance < 15.0 then
                wait = 0; local ped = dmvPeds[index]
                if ped and DoesEntityExist(ped) and distance < distanceLimit then
                    BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to speak with the DMV clerk'); EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then STDMV.Open() end
                end
            end
        end; Wait(wait)
    end
end)
AddEventHandler('onResourceStop', function(resource) if resource ~= GetCurrentResourceName() then return end; for _, ped in ipairs(dmvPeds) do if DoesEntityExist(ped) then DeletePed(ped) end end; for _, blip in ipairs(dmvBlips) do RemoveBlip(blip) end; SetNuiFocus(false, false) end)

-- One request/response bridge for every DMV read and write operation.
local readCallbacks = {
    load='st-core:server:dmv:getOverview', getOverview='st-core:server:dmv:getOverview', getVehicle='st-core:server:dmv:getVehicle',
    getTitle='st-core:server:dmv:getTitle', getHistory='st-core:server:dmv:getHistory', getLicense='st-core:server:dmv:getLicense',
    getAppointments='st-core:server:dmv:getAppointments', bookAppointment='st-core:server:dmv:bookAppointment', cancelAppointment='st-core:server:dmv:cancelAppointment'
}
local writeEvents = {
    registerVehicle='st-core:server:registerVehicle', renewRegistration='st-core:server:renewRegistration', buyInsurance='st-core:server:buyInsurance',
    renewInsurance='st-core:server:renewInsurance', customPlate='st-core:server:customPlate', submitInsuranceClaim='st-core:server:claims:submit'
}
RegisterNUICallback('request', function(data, cb)
    local action = type(data) == 'table' and data.action; local payload = type(data) == 'table' and data.data or {}
    local callbackName = readCallbacks[action]
    if not callbackName then cb({ ok=false, error='unknown_action' }); return end
    exports['qb-core']:GetCoreObject().Functions.TriggerCallback(callbackName, function(ok, result) cb({ ok=ok, data=ok and result or nil, error=ok and nil or result }) end, payload)
end)
RegisterNUICallback('mutate', function(data, cb)
    local action = type(data) == 'table' and data.action; local payload = type(data) == 'table' and data.data or {}
    local event = writeEvents[action]
    if not event then cb({ ok=false, error='unknown_action' }); return end
    TriggerServerEvent(event, payload); cb({ ok=true, pending=true })
end)
RegisterNUICallback('close', function(_, cb) SetNuiFocus(false, false); SendNUIMessage({ action='close' }); cb({ ok=true }) end)
RegisterNUICallback('saleContractIssue', function(_, cb) TriggerServerEvent('st-core:server:saleContractIssue'); cb({ok=true}) end)
RegisterNUICallback('saleContractClose', function(_, cb) TriggerServerEvent('st-core:server:saleContractClose'); cb({ok=true}) end)
RegisterNetEvent('st-core:client:dmvData', function(data) SendNUIMessage({ action='data', data=data }) end)
RegisterNetEvent('st-core:client:dmvResult', function(result) SendNUIMessage({ action='result', result=result }) end)
RegisterNetEvent('st-core:client:claims:vehicles', function(vehicles) SendNUIMessage({ action='claimVehicles', vehicles=vehicles or {} }) end)
RegisterNetEvent('st-core:client:claims:result', function(success,result) SendNUIMessage({ action='claimResult', success=success, result=result }) end)
