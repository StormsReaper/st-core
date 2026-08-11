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

local function getFramework()
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return nil
end

local function registrationPlateExists(plate)
    return MySQL.single.await('SELECT id FROM st_vehicle_registrations WHERE plate = ? LIMIT 1', { plate }) ~= nil
end

local function plateExists(plate)
    if registrationPlateExists(plate) then return true end
    local framework = getFramework()
    if framework == 'qbcore' then return MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) ~= nil end
    if framework == 'esx' then return MySQL.single.await('SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate }) ~= nil end
    return false
end

local function generateUniquePlate()
    for _ = 1, (Config.Plate.GenerationAttempts or 50) do
        local plate = generateStandardPlate()
        if not plateExists(plate) then return plate end
    end
end

local function generateVIN()
    for _ = 1, 50 do
        local vin = ('ST%s%s'):format(os.date('%y'), randomChars(12, 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'))
        if not MySQL.single.await('SELECT id FROM st_vehicle_registrations WHERE vin = ? LIMIT 1', { vin })
            and not MySQL.single.await('SELECT id FROM st_vehicle_records WHERE vin = ? LIMIT 1', { vin }) then return vin end
    end
end

local function decodeVehicleModel(value)
    if type(value) ~= 'string' then return nil end
    local ok, data = pcall(json.decode, value)
    if ok and type(data) == 'table' then return data.model or data.vehicle or data.name end
    return value
end

local function getFrameworkVehicle(ownerIdentifier, plate)
    plate = STValidation.NormalizePlate(plate)
    local framework = getFramework()
    if framework == 'qbcore' then return MySQL.single.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1', { ownerIdentifier, plate }) end
    if framework == 'esx' then return MySQL.single.await('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1', { ownerIdentifier, plate }) end
end

CreateThread(function() math.randomseed(os.time() + GetGameTimer()) end)
STVehicles = {}
function STVehicles.GeneratePlate() return generateUniquePlate() end
function STVehicles.GenerateVIN() return generateVIN() end
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
function STVehicles.GetVehicleRecordByPlate(plate)
    return MySQL.single.await('SELECT * FROM st_vehicle_records WHERE plate = ? LIMIT 1', { STValidation.NormalizePlate(plate) })
end
function STVehicles.GetVehicleRecordByVIN(vin)
    if type(vin) ~= 'string' then return nil end
    return MySQL.single.await('SELECT * FROM st_vehicle_records WHERE vin = ? LIMIT 1', { vin:upper() })
end
function STVehicles.GetOwnedVehicleByPlate(ownerIdentifier, plate)
    if not STValidation.IsIdentifier(ownerIdentifier) then return nil end
    return getFrameworkVehicle(ownerIdentifier, plate)
end
function STVehicles.GetVehicleModel(record)
    return record and decodeVehicleModel(record.vehicle) or nil
end
function STVehicles.UpdateOwnedVehiclePlate(ownerIdentifier, oldPlate, newPlate)
    if not STValidation.IsIdentifier(ownerIdentifier) then return false, 'invalid_owner_identifier' end
    oldPlate, newPlate = STValidation.NormalizePlate(oldPlate), STValidation.NormalizePlate(newPlate)
    if oldPlate == '' or newPlate == '' or oldPlate == newPlate then return true end
    local framework = getFramework()
    if framework == 'qbcore' then
        if MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { newPlate }) then return false, 'plate_already_in_framework_database' end
        local affected = MySQL.update.await('UPDATE player_vehicles SET plate = ? WHERE citizenid = ? AND plate = ?', { newPlate, ownerIdentifier, oldPlate })
        return affected == 1, affected == 1 and nil or 'framework_vehicle_update_failed'
    elseif framework == 'esx' then
        if MySQL.single.await('SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { newPlate }) then return false, 'plate_already_in_framework_database' end
        local affected = MySQL.update.await('UPDATE owned_vehicles SET plate = ? WHERE owner = ? AND plate = ?', { newPlate, ownerIdentifier, oldPlate })
        return affected == 1, affected == 1 and nil or 'framework_vehicle_update_failed'
    end
    return false, 'unsupported_framework'
end
function STVehicles.UpdateFrameworkOwner(oldOwnerIdentifier, newOwnerIdentifier, plate)
    local framework = getFramework()
    if framework == 'qbcore' then
        local affected = MySQL.update.await('UPDATE player_vehicles SET citizenid = ? WHERE citizenid = ? AND plate = ?', { newOwnerIdentifier, oldOwnerIdentifier, plate })
        return affected == 1, affected == 1 and nil or 'framework_owner_update_failed'
    elseif framework == 'esx' then
        local affected = MySQL.update.await('UPDATE owned_vehicles SET owner = ? WHERE owner = ? AND plate = ?', { newOwnerIdentifier, oldOwnerIdentifier, plate })
        return affected == 1, affected == 1 and nil or 'framework_owner_update_failed'
    end
    return false, 'unsupported_framework'
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
    local vin = data.vin or generateVIN()
    if not vin then return false, 'vin_generation_failed' end
    local now, expiresAt = os.time(), os.time() + ((Config.Registration.DurationDays or 30) * 86400)
    local insertId = MySQL.insert.await([[
        INSERT INTO st_vehicle_registrations
        (vehicle_identifier, vin, owner_identifier, owner_name, vehicle_model, vehicle_display_name, purchase_price, purchase_type, payment_method, financed, dealership, plate, plate_type, registered_at, expires_at, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
    ]], { data.vehicleIdentifier, vin, data.ownerIdentifier, data.ownerName or 'Unknown', data.vehicleModel, data.vehicleDisplayName, tonumber(data.purchasePrice) or 0, data.purchaseType, data.paymentMethod, data.financed and 1 or 0, data.dealership, plate, isCustom and 'custom' or 'standard', now, expiresAt })
    if not insertId then return false, 'database_insert_failed' end
    STVehicles.SyncVehicleRecord(data.vehicleIdentifier)
    debugPrint(('Registered vehicle %s VIN %s plate %s'):format(data.vehicleIdentifier, vin, plate))
    return true, STVehicles.GetRegistration(data.vehicleIdentifier)
end
function STVehicles.SyncVehicleRecord(vehicleIdentifier)
    local registration = STVehicles.GetRegistration(vehicleIdentifier)
    if not registration then return false, 'registration_not_found' end
    local insurance = MySQL.single.await('SELECT policy_number, status, expires_at FROM st_vehicle_insurance WHERE vehicle_identifier = ? ORDER BY id DESC LIMIT 1', { vehicleIdentifier })
    MySQL.query.await([[
        INSERT INTO st_vehicle_records
        (vehicle_identifier, vin, plate, owner_identifier, owner_name, vehicle_model, vehicle_display_name, purchase_price, dealership, registration_status, registration_expires_at, insurance_policy_number, insurance_status, insurance_expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE vin=VALUES(vin), plate=VALUES(plate), owner_identifier=VALUES(owner_identifier), owner_name=VALUES(owner_name), vehicle_model=VALUES(vehicle_model), vehicle_display_name=VALUES(vehicle_display_name), purchase_price=VALUES(purchase_price), dealership=VALUES(dealership), registration_status=VALUES(registration_status), registration_expires_at=VALUES(registration_expires_at), insurance_policy_number=VALUES(insurance_policy_number), insurance_status=VALUES(insurance_status), insurance_expires_at=VALUES(insurance_expires_at), updated_at=CURRENT_TIMESTAMP
    ]], { registration.vehicle_identifier, registration.vin, registration.plate, registration.owner_identifier, registration.owner_name or 'Unknown', registration.vehicle_model, registration.vehicle_display_name, registration.purchase_price or 0, registration.dealership, registration.status, registration.expires_at, insurance and insurance.policy_number or nil, insurance and insurance.status or nil, insurance and insurance.expires_at or nil })
    return true
end
function STVehicles.RenewRegistration(vehicleIdentifier, durationDays)
    local registration = STVehicles.GetRegistration(vehicleIdentifier)
    if not registration then return false, 'registration_not_found' end
    durationDays = tonumber(durationDays) or Config.Registration.DurationDays
    if durationDays < 1 then return false, 'invalid_duration' end
    local expiresAt = math.max(os.time(), tonumber(registration.expires_at) or 0) + durationDays * 86400
    local affected = MySQL.update.await("UPDATE st_vehicle_registrations SET expires_at = ?, status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?", { expiresAt, registration.id })
    if affected ~= 1 then return false, 'database_update_failed' end
    STVehicles.SyncVehicleRecord(vehicleIdentifier)
    return true, STVehicles.GetRegistration(vehicleIdentifier)
end
function STVehicles.IsRegistered(plate)
    local registration = STVehicles.GetRegistrationByPlate(plate)
    if not registration or registration.status ~= 'active' then return false end
    return tonumber(registration.expires_at) == nil or tonumber(registration.expires_at) >= os.time()
end

exports('GenerateVehiclePlate', STVehicles.GeneratePlate)
exports('GenerateVehicleVIN', STVehicles.GenerateVIN)
exports('ValidateVehiclePlate', STVehicles.ValidatePlate)
exports('GetVehicleRegistration', STVehicles.GetRegistration)
exports('GetVehicleRegistrationByPlate', STVehicles.GetRegistrationByPlate)
exports('GetVehicleRecordByPlate', STVehicles.GetVehicleRecordByPlate)
exports('GetVehicleRecordByVIN', STVehicles.GetVehicleRecordByVIN)
exports('RegisterVehicle', STVehicles.RegisterVehicle)
exports('RenewVehicleRegistration', STVehicles.RenewRegistration)
exports('IsVehicleRegistered', STVehicles.IsRegistered)
exports('GetOwnedVehicleByPlate', STVehicles.GetOwnedVehicleByPlate)
exports('UpdateOwnedVehiclePlate', STVehicles.UpdateOwnedVehiclePlate)
exports('UpdateFrameworkVehicleOwner', STVehicles.UpdateFrameworkOwner)
exports('SyncVehicleRecord', STVehicles.SyncVehicleRecord)
