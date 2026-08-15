local QBCore = exports['qb-core']:GetCoreObject()
local function identity(source)
    local Player=QBCore.Functions.GetPlayer(source); if not Player then return nil end
    local c=Player.PlayerData.charinfo or {}; return Player.PlayerData.citizenid,((c.firstname or '')..' '..(c.lastname or '')):gsub('^%s*(.-)%s*$','%1')
end
local function ownedVehicle(source,plate)
    local id=identity(source); if not id then return nil,'player_not_found' end
    local r=STVehicles.GetRegistrationByPlate(plate)
    if r and r.owner_identifier==id then return r end
    local p=STValidation.NormalizePlate(plate); local row=MySQL.single.await('SELECT plate,vehicle FROM player_vehicles WHERE citizenid=? AND UPPER(TRIM(plate))=? LIMIT 1',{id,p})
    if not row then return nil,'vehicle_not_owned' end
    return {plate=p,vehicle_model=row.vehicle,owner_identifier=id}
end
local function overview(source)
    local id=identity(source); if not id then return false,'player_not_found' end
    return true,{registrations=STVehicles.GetPlayerRegistrations(id) or {},vehicles=STInsuranceClaims.GetPlayerVehicles(source) or {},license=STLicenses.Get(id),appointments=STDMVServices.GetAppointments(id) or {},insurancePlans=STInsurance.GetPlans() or {}}
end
local function vehicle(source,plate)
    local r,e=ownedVehicle(source,plate); if not r then return false,e end
    if not r.vehicle_identifier then return true,{vehicle=r,unregistered=true,insurance=nil,title=nil,liens={},history={},claims={},mileage=nil} end
    return true,{vehicle=r,insurance=STInsurance.GetVehicleInsuranceByPlate(r.plate),title=STTitles.Get(r.vehicle_identifier),liens=STTitles.GetLiens(r.vehicle_identifier),history=STVehicleHistory.Get(r.vehicle_identifier,100),claims=STInsuranceClaims.GetVehicleHistory(r.vehicle_identifier),mileage=STDMVServices.GetMileage(r.vehicle_identifier)}
end
QBCore.Functions.CreateCallback('st-core:server:unified:overview',function(source,cb) cb(overview(source)) end)
QBCore.Functions.CreateCallback('st-core:server:unified:vehicle',function(source,cb,plate) cb(vehicle(source,plate)) end)
QBCore.Functions.CreateCallback('st-core:server:unified:license',function(source,cb)local id=identity(source);cb(id~=nil,id and STLicenses.Get(id) or 'player_not_found')end)
QBCore.Functions.CreateCallback('st-core:server:unified:appointments',function(source,cb)local id=identity(source);cb(id~=nil,id and STDMVServices.GetAppointments(id) or 'player_not_found')end)
QBCore.Functions.CreateCallback('st-core:server:unified:claims',function(source,cb)local id=identity(source);if not id then return cb(false,'player_not_found') end;cb(true,MySQL.query.await('SELECT * FROM st_insurance_claims WHERE claimant_identifier=? ORDER BY created_at DESC',{id}))end)
QBCore.Functions.CreateCallback('st-core:server:unified:bookAppointment',function(source,cb,data)local id,name=identity(source);if not id then return cb(false,'player_not_found')end;data=data or {};data.ownerIdentifier=id;data.ownerName=name;cb(STDMVServices.BookAppointment(data))end)
QBCore.Functions.CreateCallback('st-core:server:unified:cancelAppointment',function(source,cb,id)local owner=identity(source);if not owner then return cb(false,'player_not_found')end;cb(STDMVServices.CancelAppointment(id,owner))end)
QBCore.Functions.CreateCallback('st-core:server:unified:renewLicense',function(source,cb)local id=identity(source);if not id then return cb(false,'player_not_found')end;cb(STLicenses.Renew(id,Config.LicenseDurationDays or 365))end)
