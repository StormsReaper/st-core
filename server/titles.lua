STTitles = {}
local function titleNumber()
    for _=1,50 do
        local n=('STT-%08d'):format(math.random(0,99999999))
        if not MySQL.single.await('SELECT id FROM st_vehicle_titles WHERE title_number=? LIMIT 1',{n}) then return n end
    end
end
function STTitles.Get(vehicleIdentifier) return MySQL.single.await('SELECT * FROM st_vehicle_titles WHERE vehicle_identifier=? LIMIT 1',{vehicleIdentifier}) end
function STTitles.GetByPlate(plate)
    local r=STVehicles.GetRegistrationByPlate(plate); return r and STTitles.Get(r.vehicle_identifier) or nil
end
function STTitles.Issue(vehicleIdentifier,ownerIdentifier,ownerName,status)
    local existing=STTitles.Get(vehicleIdentifier); if existing then return true,existing end
    local n=titleNumber(); if not n then return false,'title_number_failed' end
    local id=MySQL.insert.await('INSERT INTO st_vehicle_titles (title_number,vehicle_identifier,owner_identifier,owner_name,title_status,issue_date) VALUES (?,?,?,?,?,?)',{n,vehicleIdentifier,ownerIdentifier,ownerName or 'Unknown',status or 'clear',os.time()})
    return id ~= nil, id and STTitles.Get(vehicleIdentifier) or 'database_insert_failed'
end
function STTitles.SetStatus(vehicleIdentifier,status)
    local allowed={clear=true,lien=true,salvage=true,rebuilt=true,branded=true,cancelled=true}; if not allowed[status] then return false,'invalid_status' end
    return MySQL.update.await('UPDATE st_vehicle_titles SET title_status=?,updated_at=CURRENT_TIMESTAMP WHERE vehicle_identifier=?',{status,vehicleIdentifier})==1
end
function STTitles.AddLien(vehicleIdentifier,data)
    local id=MySQL.insert.await('INSERT INTO st_vehicle_liens (vehicle_identifier,lienholder_identifier,lienholder_name,original_amount,remaining_balance,monthly_payment,next_payment_at,status) VALUES (?,?,?,?,?,?,?,\'active\')',{vehicleIdentifier,data.lienholderIdentifier,data.lienholderName,tonumber(data.originalAmount) or 0,tonumber(data.remainingBalance) or tonumber(data.originalAmount) or 0,tonumber(data.monthlyPayment) or 0,data.nextPaymentAt})
    if not id then return false,'database_insert_failed' end STTitles.SetStatus(vehicleIdentifier,'lien'); return true,id
end
function STTitles.GetLiens(vehicleIdentifier) return MySQL.query.await("SELECT * FROM st_vehicle_liens WHERE vehicle_identifier=? AND status IN ('active','defaulted','repossessed') ORDER BY id DESC",{vehicleIdentifier}) end
function STTitles.HasActiveLien(vehicleIdentifier) return MySQL.single.await("SELECT id FROM st_vehicle_liens WHERE vehicle_identifier=? AND status IN ('active','defaulted','repossessed') LIMIT 1",{vehicleIdentifier}) ~= nil end
function STTitles.ReleaseLien(lienId) local row=MySQL.single.await('SELECT vehicle_identifier FROM st_vehicle_liens WHERE id=?',{lienId}); if not row then return false,'lien_not_found' end local ok=MySQL.update.await("UPDATE st_vehicle_liens SET status='released',remaining_balance=0,updated_at=CURRENT_TIMESTAMP WHERE id=?",{lienId})==1; if ok and not STTitles.HasActiveLien(row.vehicle_identifier) then STTitles.SetStatus(row.vehicle_identifier,'clear') end return ok end
exports('GetVehicleTitle',STTitles.Get); exports('GetVehicleTitleByPlate',STTitles.GetByPlate); exports('IssueVehicleTitle',STTitles.Issue); exports('SetVehicleTitleStatus',STTitles.SetStatus); exports('AddVehicleLien',STTitles.AddLien); exports('GetVehicleLiens',STTitles.GetLiens); exports('VehicleHasActiveLien',STTitles.HasActiveLien); exports('ReleaseVehicleLien',STTitles.ReleaseLien)
