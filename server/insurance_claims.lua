STInsuranceClaims = {}
local function claimNumber() for _=1,50 do local n=('CLM-%08d'):format(math.random(0,99999999)); if not MySQL.single.await('SELECT id FROM st_insurance_claims WHERE claim_number=? LIMIT 1',{n}) then return n end end end
function STInsuranceClaims.Get(id) return MySQL.single.await('SELECT * FROM st_insurance_claims WHERE id=? LIMIT 1',{id}) end
function STInsuranceClaims.GetByNumber(n) return MySQL.single.await('SELECT * FROM st_insurance_claims WHERE claim_number=? LIMIT 1',{n}) end
function STInsuranceClaims.Create(data)
    local n=claimNumber(); if not n then return false,'number_generation_failed' end
    local id=MySQL.insert.await('INSERT INTO st_insurance_claims (claim_number,policy_id,vehicle_identifier,claimant_identifier,claimant_name,other_vehicle_identifier,other_plate,fault_percent,damage_estimate,description) VALUES (?,?,?,?,?,?,?,?,?,?)',{n,data.policyId,data.vehicleIdentifier,data.claimantIdentifier,data.claimantName,data.otherVehicleIdentifier,data.otherPlate,tonumber(data.faultPercent) or 0,tonumber(data.damageEstimate) or 0,data.description})
    return id ~= nil,id and STInsuranceClaims.Get(id) or 'database_insert_failed'
end
function STInsuranceClaims.SetStatus(id,status,payout) local ok=MySQL.update.await('UPDATE st_insurance_claims SET status=?,payout=?,updated_at=CURRENT_TIMESTAMP WHERE id=?',{status,tonumber(payout) or 0,id})==1; return ok,ok and STInsuranceClaims.Get(id) or 'database_update_failed' end
function STInsuranceClaims.GetVehicleHistory(vehicleIdentifier) return MySQL.query.await('SELECT * FROM st_insurance_claims WHERE vehicle_identifier=? ORDER BY created_at DESC',{vehicleIdentifier}) end
exports('CreateInsuranceClaim',STInsuranceClaims.Create); exports('GetInsuranceClaim',STInsuranceClaims.Get); exports('GetInsuranceClaimByNumber',STInsuranceClaims.GetByNumber); exports('SetInsuranceClaimStatus',STInsuranceClaims.SetStatus); exports('GetVehicleInsuranceClaims',STInsuranceClaims.GetVehicleHistory)
