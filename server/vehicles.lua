local function debugPrint(message) if Config.Debug then print(('[%s] %s'):format(Config.ResourceName, message)) end end
local function randomChars(length, charset) local output = {}; for i = 1, length do local index = math.random(1, #charset); output[i] = charset:sub(index, index) end; return table.concat(output) end
local function generateStandardPlate() return ('%s %s'):format(randomChars(3, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'), randomChars(3, '0123456789')) end
local function getFramework() if GetResourceState('qb-core') == 'started' then return 'qbcore' end if GetResourceState('es_extended') == 'started' then return 'esx' end return nil end
local function registrationPlateExists(plate) return MySQL.single.await('SELECT id FROM st_vehicle_registrations WHERE plate = ? LIMIT 1', { plate }) ~= nil end
local function plateExists(plate) if registrationPlateExists(plate) then return true end local framework = getFramework() if framework == 'qbcore' then return MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) ~= nil end if framework == 'esx' then return MySQL.single.await('SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate }) ~= nil end return false end
local function generateUniquePlate() for _ = 1, (Config.Plate.GenerationAttempts or 50) do local plate = generateStandardPlate(); if not plateExists(plate) then return plate end end return nil end
local function decodeVehicleModel(value) if type(value) ~= 'string' then return nil end local ok, data = pcall(json.decode, value); if ok and type(data) == 'table' then return data.model or data.vehicle or data.name end return value end
local function getFrameworkVehicle(ownerIdentifier, plate) local framework = getFramework(); plate = STValidation.NormalizePlate(plate); if framework == 'qbcore' then return MySQL.single.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1', { ownerIdentifier, plate }) elseif framework == 'esx' then return MySQL.single.await('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1', { ownerIdentifier, plate }) end return nil end
CreateThread(function() math.randomseed(os.time() + GetGameTimer()) end)
STVehicles = {}
function STVehicles.GeneratePlate() return generateUniquePlate() end
function STVehicles.ValidatePlate(plate, allowCustom) return STValidation.IsValidPlate(plate, allowCustom) end
function STVehicles.GetRegistrationByPlate(plate) plate = STValidation.NormalizePlate(plate); if not STValidation.IsValidPlate(plate, true) then return nil end return MySQL.single.await('SELECT * FROM st_vehicle_registrations WHERE plate = ? LIMIT 1', { plate }) end
function STVehicles.GetRegistration(vehicleIdentifier) if not STValidation.IsIdentifier(vehicleIdentifier) then return nil end return MySQL.single.await('SELECT * FROM st_vehicle_registrations WHERE vehicle_identifier = ? LIMIT 1', { vehicleIdentifier }) end
function STVehicles.GetVehicleRecordByPlate(plate) return MySQL.single.await('SELECT * FROM st_vehicle_records WHERE plate = ? LIMIT 1', { STValidation.NormalizePlate(plate) }) end
function STVehicles.GetOwnedVehicleByPlate(ownerIdentifier, plate) if not STValidation.IsIdentifier(ownerIdentifier) then return nil end return getFrameworkVehicle(ownerIdentifier, plate) end
function STVehicles.GetVehicleModel(record)
    if type(record) ~= 'table' then return nil end
    if record.vehicle_model and tostring(record.vehicle_model) ~= '' then return tostring(record.vehicle_model) end
    if record.model and tostring(record.model) ~= '' then local decoded = decodeVehicleModel(record.model); if decoded and tostring(decoded) ~= '' then return tostring(decoded) end end
    if record.vehicle and tostring(record.vehicle) ~= '' then local decoded = decodeVehicleModel(record.vehicle); if decoded and tostring(decoded) ~= '' then return tostring(decoded) end end
    if record.display_name and tostring(record.display_name) ~= '' then return tostring(record.display_name) end
    return nil
end
function STVehicles.LookupOwnedVehicleForDMV(ownerIdentifier, ownerName, plate)
    plate = STValidation.NormalizePlate(plate); if plate == '' or #plate > 12 then return nil, 'invalid_plate' end
    local existingRegistration = STVehicles.GetRegistrationByPlate(plate)
    local record = getFrameworkVehicle(ownerIdentifier, plate)
    if existingRegistration and record then return { alreadyRegistered = true, registration = existingRegistration, framework = record, plate = plate } end
    if not record then return nil, 'vehicle_not_found_or_not_owned' end
    local model = STVehicles.GetVehicleModel(record) or record.model or record.vehicle or 'unknown'
    local vehicleIdentifier = ('plate:%s'):format(plate:gsub('%s+', ''))
    local existing = STVehicles.GetRegistration(vehicleIdentifier)
    if existing then return { alreadyRegistered = true, registration = existing, framework = record, plate = plate } end
    return { alreadyRegistered = false, vehicleIdentifier = vehicleIdentifier, plate = plate, model = tostring(model), displayName = tostring(model), ownerIdentifier = ownerIdentifier, ownerName = ownerName or 'Unknown', purchasePrice = tonumber(record.price or record.purchase_price) or 0, purchaseType = record.payment or record.paymentMethod, paymentMethod = record.payment or record.paymentMethod, financed = record.finance == 1 or record.finance == true or record.financed == 1 or record.financed == true, framework = record }
end
function STVehicles.UpdateOwnedVehiclePlate(ownerIdentifier, oldPlate, newPlate)
    if not STValidation.IsIdentifier(ownerIdentifier) then return false, 'invalid_owner_identifier' end
    oldPlate = STValidation.NormalizePlate(oldPlate); newPlate = STValidation.NormalizePlate(newPlate); if oldPlate == '' or newPlate == '' or oldPlate == newPlate then return true end
    local framework = getFramework(); local affected
    if framework == 'qbcore' then
        if MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { newPlate }) then return false, 'plate_already_in_framework_database' end
        affected = MySQL.update.await('UPDATE player_vehicles SET plate = ? WHERE citizenid = ? AND plate = ?', { newPlate, ownerIdentifier, oldPlate })
    elseif framework == 'esx' then
        if MySQL.single.await('SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { newPlate }) then return false, 'plate_already_in_framework_database' end
        affected = MySQL.update.await('UPDATE owned_vehicles SET plate = ? WHERE owner = ? AND plate = ?', { newPlate, ownerIdentifier, oldPlate })
    else return false, 'unsupported_framework' end
    if affected == 1 and GetResourceState('ox_inventory') == 'started' then pcall(function() exports.ox_inventory:UpdateVehicle(oldPlate, newPlate) end) end
    return affected == 1, affected == 1 and nil or 'framework_vehicle_update_failed'
end
function STVehicles.UpdateFrameworkOwner(oldOwnerIdentifier, newOwnerIdentifier, plate)
    local framework = getFramework(); local affected
    if framework == 'qbcore' then affected = MySQL.update.await('UPDATE player_vehicles SET citizenid = ? WHERE citizenid = ? AND plate = ?', { newOwnerIdentifier, oldOwnerIdentifier, plate }) elseif framework == 'esx' then affected = MySQL.update.await('UPDATE owned_vehicles SET owner = ? WHERE owner = ? AND plate = ?', { newOwnerIdentifier, oldOwnerIdentifier, plate }) else return false, 'unsupported_framework' end
    return affected == 1, affected == 1 and nil or 'framework_owner_update_failed'
end
function STVehicles.RegisterVehicle(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    if not STValidation.IsIdentifier(data.ownerIdentifier) or not STValidation.IsIdentifier(data.vehicleIdentifier) then return false, 'invalid_identity' end
    if STVehicles.GetRegistration(data.vehicleIdentifier) then return false, 'vehicle_already_registered' end
    local plate = data.plate and STValidation.NormalizePlate(data.plate) or generateUniquePlate()
    local isCustom = data.plate ~= nil
    if not plate then return false, 'plate_generation_failed' end
    if isCustom then if not STValidation.IsCustomPlate(plate) then return false, 'invalid_custom_plate' end if plateExists(plate) then return false, 'plate_already_in_use' end end
    local now = os.time(); local expiresAt = now + ((Config.Registration.DurationDays or 30) * 86400)
    local insertId = MySQL.insert.await([[INSERT INTO st_vehicle_registrations (vehicle_identifier,owner_identifier,owner_name,vehicle_model,vehicle_display_name,purchase_price,purchase_type,payment_method,financed,dealership,plate,plate_type,registered_at,expires_at,status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'active')]], { data.vehicleIdentifier, data.ownerIdentifier, data.ownerName or 'Unknown', data.vehicleModel, data.vehicleDisplayName, tonumber(data.purchasePrice) or 0, data.purchaseType, data.paymentMethod, data.financed and 1 or 0, data.dealership, plate, isCustom and 'custom' or 'standard', now, expiresAt })
    if not insertId then return false, 'database_insert_failed' end
    STVehicles.SyncVehicleRecord(data.vehicleIdentifier); debugPrint(('Registered vehicle %s plate %s'):format(data.vehicleIdentifier, plate)); return true, STVehicles.GetRegistration(data.vehicleIdentifier)
end
function STVehicles.SyncVehicleRecord(vehicleIdentifier)
    local registration = STVehicles.GetRegistration(vehicleIdentifier); if not registration then return false, 'registration_not_found' end
    local insurance = MySQL.single.await('SELECT policy_number,status,expires_at FROM st_vehicle_insurance WHERE vehicle_identifier=? ORDER BY id DESC LIMIT 1', { vehicleIdentifier })
    MySQL.query.await([[INSERT INTO st_vehicle_records (vehicle_identifier,plate,owner_identifier,owner_name,vehicle_model,vehicle_display_name,purchase_price,dealership,registration_status,registration_expires_at,insurance_policy_number,insurance_status,insurance_expires_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE plate=VALUES(plate),owner_identifier=VALUES(owner_identifier),owner_name=VALUES(owner_name),vehicle_model=VALUES(vehicle_model),vehicle_display_name=VALUES(vehicle_display_name),purchase_price=VALUES(purchase_price),dealership=VALUES(dealership),registration_status=VALUES(registration_status),registration_expires_at=VALUES(registration_expires_at),insurance_policy_number=VALUES(insurance_policy_number),insurance_status=VALUES(insurance_status),insurance_expires_at=VALUES(insurance_expires_at),updated_at=CURRENT_TIMESTAMP]], { registration.vehicle_identifier, registration.plate, registration.owner_identifier, registration.owner_name or 'Unknown', registration.vehicle_model, registration.vehicle_display_name, registration.purchase_price or 0, registration.dealership, registration.status, registration.expires_at, insurance and insurance.policy_number or nil, insurance and insurance.status or nil, insurance and insurance.expires_at or nil })
    return true
end
function STVehicles.RenewRegistration(vehicleIdentifier, durationDays)
    local registration = STVehicles.GetRegistration(vehicleIdentifier); if not registration then return false, 'registration_not_found' end
    durationDays = tonumber(durationDays) or Config.Registration.DurationDays; if durationDays < 1 then return false, 'invalid_duration' end
    local expiresAt = math.max(os.time(), tonumber(registration.expires_at) or 0) + (durationDays * 86400)
    if MySQL.update.await("UPDATE st_vehicle_registrations SET expires_at=?,status='active',updated_at=CURRENT_TIMESTAMP WHERE id=?", { expiresAt, registration.id }) ~= 1 then return false, 'database_update_failed' end
    STVehicles.SyncVehicleRecord(vehicleIdentifier); return true, STVehicles.GetRegistration(vehicleIdentifier)
end
function STVehicles.IsRegistered(plate) local registration = STVehicles.GetRegistrationByPlate(plate); if not registration or registration.status ~= 'active' then return false end return tonumber(registration.expires_at) == nil or tonumber(registration.expires_at) >= os.time() end
exports('GenerateVehiclePlate', STVehicles.GeneratePlate); exports('ValidateVehiclePlate', STVehicles.ValidatePlate); exports('GetVehicleRegistration', STVehicles.GetRegistration); exports('GetVehicleRegistrationByPlate', STVehicles.GetRegistrationByPlate); exports('GetVehicleRecordByPlate', STVehicles.GetVehicleRecordByPlate); exports('RegisterVehicle', STVehicles.RegisterVehicle); exports('RenewVehicleRegistration', STVehicles.RenewRegistration); exports('IsVehicleRegistered', STVehicles.IsRegistered); exports('GetOwnedVehicleByPlate', STVehicles.GetOwnedVehicleByPlate); exports('UpdateOwnedVehiclePlate', STVehicles.UpdateOwnedVehiclePlate); exports('UpdateFrameworkVehicleOwner', STVehicles.UpdateFrameworkOwner); exports('SyncVehicleRecord', STVehicles.SyncVehicleRecord); exports('LookupOwnedVehicleForDMV', STVehicles.LookupOwnedVehicleForDMV)
