local function debugPrint(message)
    if Config.Debug then print(('[%s] %s'):format(Config.ResourceName, message)) end
end

local function randomChars(length, charset)
    local output = {}
    for i = 1, length do
        local index = math.random(1, #charset)
        output[i] = charset:sub(index, index)
    end
    return table.concat(output)
end

local function generateStandardPlate()
    return ('%s %s'):format(randomChars(3, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'), randomChars(3, '0123456789'))
end

local function plateExists(plate)
    return MySQL.single.await('SELECT id FROM st_vehicle_registrations WHERE plate = ? LIMIT 1', { plate }) ~= nil
end

local function generateUniquePlate()
    for _ = 1, (Config.Plate.GenerationAttempts or 50) do
        local plate = generateStandardPlate()
        if not plateExists(plate) then return plate end
    end
    return nil
end

CreateThread(function() math.randomseed(os.time() + GetGameTimer()) end)
STVehicles = {}

function STVehicles.GeneratePlate() return generateUniquePlate() end
function STVehicles.ValidatePlate(plate, allowCustom) return STValidation.IsValidPlate(plate, allowCustom) end

function STVehicles.GetRegistrationByPlate(plate)
    plate = STValidation.NormalizePlate(plate)
    if not STValidation.IsValidPlate(plate, true) then return nil end
    return MySQL.single.await('SELECT * FROM st_vehicle_registrations WHERE plate = ? LIMIT 1', { plate })
end

function STVehicles.GetRegistration(vehicleIdentifier)
    if not STValidation.IsIdentifier(vehicleIdentifier) then return nil end
    return MySQL.single.await('SELECT * FROM st_vehicle_registrations WHERE vehicle_identifier = ? LIMIT 1', { vehicleIdentifier })
end

function STVehicles.RegisterVehicle(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    if not STValidation.IsIdentifier(data.ownerIdentifier) then return false, 'invalid_owner_identifier' end
    if not STValidation.IsIdentifier(data.vehicleIdentifier) then return false, 'invalid_vehicle_identifier' end
    if STVehicles.GetRegistration(data.vehicleIdentifier) then return false, 'vehicle_already_registered' end

    local plate = data.plate and STValidation.NormalizePlate(data.plate) or nil
    local isCustom = plate ~= nil
    if isCustom then
        if not STValidation.IsCustomPlate(plate) then return false, 'invalid_custom_plate' end
        if plateExists(plate) then return false, 'plate_already_in_use' end
    else
        plate = generateUniquePlate()
        if not plate then return false, 'plate_generation_failed' end
    end

    local now = os.time()
    local expiresAt = now + ((Config.Registration.DurationDays or 30) * 86400)
    local insertId = MySQL.insert.await([[
        INSERT INTO st_vehicle_registrations
            (vehicle_identifier, owner_identifier, plate, plate_type, registered_at, expires_at, status)
        VALUES (?, ?, ?, ?, ?, ?, 'active')
    ]], { data.vehicleIdentifier, data.ownerIdentifier, plate, isCustom and 'custom' or 'standard', now, expiresAt })

    if not insertId then return false, 'database_insert_failed' end
    debugPrint(('Registered vehicle %s with plate %s'):format(data.vehicleIdentifier, plate))
    return true, STVehicles.GetRegistration(data.vehicleIdentifier)
end

function STVehicles.RenewRegistration(vehicleIdentifier, durationDays)
    local registration = STVehicles.GetRegistration(vehicleIdentifier)
    if not registration then return false, 'registration_not_found' end
    durationDays = tonumber(durationDays) or Config.Registration.DurationDays
    if durationDays < 1 then return false, 'invalid_duration' end
    local baseTime = math.max(os.time(), tonumber(registration.expires_at) or 0)
    local expiresAt = baseTime + (durationDays * 86400)
    local affected = MySQL.update.await('UPDATE st_vehicle_registrations SET expires_at = ?, status = \'active\', updated_at = CURRENT_TIMESTAMP WHERE id = ?', { expiresAt, registration.id })
    return affected == 1, affected == 1 and STVehicles.GetRegistration(vehicleIdentifier) or 'database_update_failed'
end

function STVehicles.IsRegistered(plate)
    local registration = STVehicles.GetRegistrationByPlate(plate)
    if not registration or registration.status ~= 'active' then return false end
    local expiresAt = tonumber(registration.expires_at)
    return expiresAt == nil or expiresAt >= os.time()
end

exports('GenerateVehiclePlate', STVehicles.GeneratePlate)
exports('ValidateVehiclePlate', STVehicles.ValidatePlate)
exports('GetVehicleRegistration', STVehicles.GetRegistration)
exports('GetVehicleRegistrationByPlate', STVehicles.GetRegistrationByPlate)
exports('RegisterVehicle', STVehicles.RegisterVehicle)
exports('RenewVehicleRegistration', STVehicles.RenewRegistration)
exports('IsVehicleRegistered', STVehicles.IsRegistered)
