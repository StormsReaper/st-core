STDMVAPI = {}

local QBCore = exports['qb-core']:GetCoreObject()

local function getPlayer(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return nil end
    local char = player.PlayerData.charinfo or {}
    local name = ((char.firstname or '') .. ' ' .. (char.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
    return player, player.PlayerData.citizenid, name
end

local function vehicleForOwner(identifier, plate)
    local registration = STVehicles.GetRegistrationByPlate(plate)
    if not registration or registration.owner_identifier ~= identifier then return nil end
    return registration
end

function STDMVAPI.GetOverview(source)
    local player, identifier = getPlayer(source)
    if not player then return false, 'player_not_found' end
    return true, {
        vehicles = STVehicles.GetPlayerVehicles(identifier) or {},
        registrations = STVehicles.GetPlayerRegistrations(identifier) or {},
        license = STLicenses.Get(identifier),
        appointments = STDMVServices.GetAppointments(identifier),
        insurancePlans = STInsurance.GetPlans(),
    }
end

function STDMVAPI.GetVehicle(source, plate)
    local player, identifier = getPlayer(source)
    if not player then return false, 'player_not_found' end
    local registration = vehicleForOwner(identifier, plate)
    if not registration then return false, 'vehicle_not_owned' end
    local vehicleIdentifier = registration.vehicle_identifier
    return true, {
        vehicle = registration,
        insurance = STInsurance.GetVehicleInsuranceByPlate(registration.plate),
        title = STTitles.Get(vehicleIdentifier),
        liens = STTitles.GetLiens(vehicleIdentifier),
        history = STVehicleHistory.Get(vehicleIdentifier, 100),
        claims = STInsuranceClaims.GetVehicleHistory(vehicleIdentifier),
        mileage = STDMVServices.GetMileage(vehicleIdentifier),
    }
end

function STDMVAPI.GetLicense(source)
    local player, identifier = getPlayer(source)
    if not player then return false, 'player_not_found' end
    return true, STLicenses.Get(identifier)
end

function STDMVAPI.GetAppointments(source)
    local player, identifier = getPlayer(source)
    if not player then return false, 'player_not_found' end
    return true, STDMVServices.GetAppointments(identifier)
end

function STDMVAPI.BookAppointment(source, data)
    local player, identifier, name = getPlayer(source)
    if not player then return false, 'player_not_found' end
    data = type(data) == 'table' and data or {}
    data.ownerIdentifier, data.ownerName = identifier, name
    return STDMVServices.BookAppointment(data)
end

function STDMVAPI.CancelAppointment(source, appointmentId)
    local player, identifier = getPlayer(source)
    if not player then return false, 'player_not_found' end
    local appointment = MySQL.single.await('SELECT id FROM st_dmv_appointments WHERE id = ? AND owner_identifier = ? AND status = \'scheduled\' LIMIT 1', { appointmentId, identifier })
    if not appointment then return false, 'appointment_not_found' end
    return STDMVServices.CancelAppointment(appointmentId)
end

function STDMVAPI.GetTitle(source, plate)
    local player, identifier = getPlayer(source)
    if not player then return false, 'player_not_found' end
    local registration = vehicleForOwner(identifier, plate)
    if not registration then return false, 'vehicle_not_owned' end
    return true, { title = STTitles.Get(registration.vehicle_identifier), liens = STTitles.GetLiens(registration.vehicle_identifier) }
end

function STDMVAPI.GetHistory(source, plate)
    local player, identifier = getPlayer(source)
    if not player then return false, 'player_not_found' end
    local registration = vehicleForOwner(identifier, plate)
    if not registration then return false, 'vehicle_not_owned' end
    return true, {
        history = STVehicleHistory.Get(registration.vehicle_identifier, 100),
        claims = STInsuranceClaims.GetVehicleHistory(registration.vehicle_identifier),
        mileage = STDMVServices.GetMileage(registration.vehicle_identifier),
    }
end

local function register(name, handler)
    QBCore.Functions.CreateCallback(name, function(source, cb, data)
        local ok, result = handler(source, data)
        cb(ok, result)
    end)
end

register('st-core:server:dmv:getOverview', STDMVAPI.GetOverview)
register('st-core:server:dmv:getVehicle', STDMVAPI.GetVehicle)
register('st-core:server:dmv:getLicense', STDMVAPI.GetLicense)
register('st-core:server:dmv:getAppointments', STDMVAPI.GetAppointments)
register('st-core:server:dmv:bookAppointment', STDMVAPI.BookAppointment)
register('st-core:server:dmv:cancelAppointment', STDMVAPI.CancelAppointment)
register('st-core:server:dmv:getTitle', STDMVAPI.GetTitle)
register('st-core:server:dmv:getHistory', STDMVAPI.GetHistory)

exports('GetDMVOverview', STDMVAPI.GetOverview)
exports('GetDMVVehicle', STDMVAPI.GetVehicle)
exports('GetDMVLicense', STDMVAPI.GetLicense)
exports('GetDMVAppointments', STDMVAPI.GetAppointments)
exports('BookDMVAppointment', STDMVAPI.BookAppointment)
exports('CancelDMVAppointment', STDMVAPI.CancelAppointment)
exports('GetDMVTitle', STDMVAPI.GetTitle)
exports('GetDMVVehicleHistory', STDMVAPI.GetHistory)
