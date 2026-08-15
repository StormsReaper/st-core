STInsuranceClaims = {}

local function claimNumber()
    for _ = 1, 50 do
        local n = ('CLM-%08d'):format(math.random(0, 99999999))
        if not MySQL.single.await('SELECT id FROM st_insurance_claims WHERE claim_number = ? LIMIT 1', { n }) then return n end
    end
end

function STInsuranceClaims.Get(id) return MySQL.single.await('SELECT * FROM st_insurance_claims WHERE id = ? LIMIT 1', { id }) end
function STInsuranceClaims.GetByNumber(n) return MySQL.single.await('SELECT * FROM st_insurance_claims WHERE claim_number = ? LIMIT 1', { n }) end
function STInsuranceClaims.GetPlayerVehicles(source)
    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end
    return MySQL.query.await([[SELECT pv.plate, pv.vehicle, r.vehicle_identifier, r.registration_number, r.status AS registration_status, r.expires_at AS registration_expires_at, i.id AS policy_id, i.policy_number, i.status AS insurance_status, i.expires_at AS insurance_expires_at, ip.name AS insurance_plan FROM player_vehicles pv LEFT JOIN st_vehicle_registrations r ON r.plate = UPPER(TRIM(pv.plate)) AND r.owner_identifier = pv.citizenid LEFT JOIN st_vehicle_insurance i ON i.vehicle_identifier = r.vehicle_identifier LEFT JOIN st_insurance_plans ip ON ip.id = i.plan_id WHERE pv.citizenid = ? ORDER BY pv.plate ASC]], { Player.PlayerData.citizenid })
end
function STInsuranceClaims.CreateForPlayer(source, data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, 'player_not_found' end
    local plate = STValidation.NormalizePlate(data.plate)
    if not plate then return false, 'invalid_plate' end
    local vehicle = MySQL.single.await([[SELECT pv.plate, pv.vehicle, r.vehicle_identifier, i.id AS policy_id, i.policy_number, i.status AS insurance_status, i.expires_at AS insurance_expires_at FROM player_vehicles pv LEFT JOIN st_vehicle_registrations r ON r.plate = UPPER(TRIM(pv.plate)) AND r.owner_identifier = pv.citizenid LEFT JOIN st_vehicle_insurance i ON i.vehicle_identifier = r.vehicle_identifier WHERE pv.citizenid = ? AND UPPER(TRIM(pv.plate)) = ? LIMIT 1]], { Player.PlayerData.citizenid, plate })
    if not vehicle or not vehicle.policy_id then return false, 'vehicle_not_insured' end
    if vehicle.insurance_status ~= 'active' or tonumber(vehicle.insurance_expires_at or 0) < os.time() then return false, 'insurance_not_active' end
    local description = type(data.description) == 'string' and data.description:sub(1, 2000) or ''
    if #description < 10 then return false, 'description_too_short' end
    local incidentType = type(data.incidentType) == 'string' and data.incidentType:sub(1, 40) or 'other'
    local incidentAt = tonumber(data.incidentAt) or os.time()
    local location = type(data.location) == 'string' and data.location:sub(1, 200) or nil
    local n = claimNumber()
    if not n then return false, 'number_generation_failed' end
    local claimantName = ((Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname) or '') .. ' ' .. ((Player.PlayerData.charinfo and Player.PlayerData.charinfo.lastname) or '')
    local id = MySQL.insert.await([[INSERT INTO st_insurance_claims (claim_number, policy_id, vehicle_identifier, claimant_identifier, claimant_name, other_vehicle_identifier, other_plate, fault_percent, damage_estimate, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { n, vehicle.policy_id, vehicle.vehicle_identifier, Player.PlayerData.citizenid, claimantName, data.otherVehicleIdentifier, data.otherPlate, tonumber(data.faultPercent) or 0, tonumber(data.damageEstimate) or 0, ('[%s]%s%s'):format(incidentType, location and (' Location: ' .. location .. ' |') or '', description) })
    if not id then return false, 'database_insert_failed' end
    return true, STInsuranceClaims.Get(id)
end
function STInsuranceClaims.SetStatus(id, status, payout) local ok = MySQL.update.await('UPDATE st_insurance_claims SET status = ?, payout = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', { status, tonumber(payout) or 0, id }) == 1; return ok, ok and STInsuranceClaims.Get(id) or 'database_update_failed' end
function STInsuranceClaims.GetVehicleHistory(vehicleIdentifier) return MySQL.query.await('SELECT * FROM st_insurance_claims WHERE vehicle_identifier = ? ORDER BY created_at DESC', { vehicleIdentifier }) end

RegisterNetEvent('st-core:server:claims:getVehicles', function()
    local source = source
    TriggerClientEvent('st-core:client:claims:vehicles', source, STInsuranceClaims.GetPlayerVehicles(source))
end)
RegisterNetEvent('st-core:server:claims:submit', function(data)
    local source = source
    local ok, result = STInsuranceClaims.CreateForPlayer(source, data)
    TriggerClientEvent('st-core:client:claims:result', source, ok, result)
end)

exports('CreateInsuranceClaim', STInsuranceClaims.CreateForPlayer)
exports('GetInsuranceClaim', STInsuranceClaims.Get)
exports('GetInsuranceClaimByNumber', STInsuranceClaims.GetByNumber)
exports('SetInsuranceClaimStatus', STInsuranceClaims.SetStatus)
exports('GetVehicleInsuranceClaims', STInsuranceClaims.GetVehicleHistory)
exports('GetPlayerClaimVehicles', STInsuranceClaims.GetPlayerVehicles)
