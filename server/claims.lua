STClaims = {}

local function normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    return STValidation.NormalizePlate(plate)
end

function STClaims.GetPlayerVehicles(source)
    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end
    local citizenid = Player.PlayerData.citizenid
    return MySQL.query.await([[SELECT pv.plate, pv.vehicle, pv.mods, pv.citizenid, r.vehicle_identifier, r.registration_number, r.status AS registration_status, r.expires_at AS registration_expires_at, i.policy_number, i.status AS insurance_status, i.expires_at AS insurance_expires_at, ip.name AS insurance_plan FROM player_vehicles pv LEFT JOIN st_vehicle_registrations r ON r.plate = UPPER(TRIM(pv.plate)) AND r.owner_identifier = pv.citizenid LEFT JOIN st_vehicle_insurance i ON i.vehicle_identifier = r.vehicle_identifier LEFT JOIN st_insurance_plans ip ON ip.id = i.plan_id WHERE pv.citizenid = ? ORDER BY pv.plate ASC]], { citizenid })
end

function STClaims.Create(source, data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    local plate = normalizePlate(data.plate)
    if not plate then return false, 'invalid_plate' end
    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, 'player_not_found' end
    local citizenid = Player.PlayerData.citizenid
    local vehicle = MySQL.single.await([[SELECT pv.plate, pv.vehicle, r.vehicle_identifier, i.id AS insurance_id, i.policy_number, i.status AS insurance_status, i.expires_at AS insurance_expires_at FROM player_vehicles pv LEFT JOIN st_vehicle_registrations r ON r.plate = UPPER(TRIM(pv.plate)) AND r.owner_identifier = pv.citizenid LEFT JOIN st_vehicle_insurance i ON i.vehicle_identifier = r.vehicle_identifier WHERE pv.citizenid = ? AND UPPER(TRIM(pv.plate)) = ? LIMIT 1]], { citizenid, plate })
    if not vehicle then return false, 'vehicle_not_owned' end
    if not vehicle.insurance_id or vehicle.insurance_status ~= 'active' or tonumber(vehicle.insurance_expires_at or 0) < os.time() then return false, 'insurance_not_active' end
    local claimNumber = nil
    for _ = 1, 50 do
        local candidate = ('CLM-%08d'):format(math.random(0, 99999999))
        if not MySQL.single.await('SELECT id FROM st_insurance_claims WHERE claim_number = ? LIMIT 1', { candidate }) then claimNumber = candidate break end
    end
    if not claimNumber then return false, 'claim_number_generation_failed' end
    local description = type(data.description) == 'string' and data.description:sub(1, 2000) or ''
    if #description < 10 then return false, 'description_too_short' end
    local incidentType = type(data.incidentType) == 'string' and data.incidentType:sub(1, 40) or 'other'
    local incidentAt = tonumber(data.incidentAt) or os.time()
    local location = type(data.location) == 'string' and data.location:sub(1, 200) or nil
    local insertId = MySQL.insert.await([[INSERT INTO st_insurance_claims (claim_number, insurance_id, vehicle_identifier, owner_identifier, plate, incident_type, incident_at, location, description, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'submitted', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)]], { claimNumber, vehicle.insurance_id, vehicle.vehicle_identifier, citizenid, plate, incidentType, incidentAt, location, description })
    if not insertId then return false, 'database_insert_failed' end
    return true, MySQL.single.await('SELECT * FROM st_insurance_claims WHERE id = ?', { insertId })
end

RegisterNetEvent('st-core:server:claims:getVehicles', function()
    local source = source
    TriggerClientEvent('st-core:client:claims:vehicles', source, STClaims.GetPlayerVehicles(source))
end)

RegisterNetEvent('st-core:server:claims:submit', function(data)
    local source = source
    local success, result = STClaims.Create(source, data)
    TriggerClientEvent('st-core:client:claims:result', source, success, result)
end)

exports('GetPlayerClaimVehicles', STClaims.GetPlayerVehicles)
exports('CreateInsuranceClaim', STClaims.Create)
