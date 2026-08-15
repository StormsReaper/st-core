STMDT = {}
function STMDT.GetVehicleByPlate(plate)
    local r=STVehicles.GetRegistrationByPlate(plate); if not r then return nil end
    local insurance=STInsurance.GetVehicleInsuranceByPlate(plate) or {insured=false,status='none',plate=r.plate}
    local title=STTitles.Get(r.vehicle_identifier)
    local liens=STTitles.GetLiens(r.vehicle_identifier)
    local history=STVehicleHistory.Get(r.vehicle_identifier,100)
    local enforcement=STEnforcement.GetVehicle(r.vehicle_identifier)
    local mileage=MySQL.single.await('SELECT mileage FROM st_vehicle_mileage WHERE vehicle_identifier=? ORDER BY id DESC LIMIT 1',{r.vehicle_identifier})
    return {vehicle_identifier=r.vehicle_identifier,plate=r.plate,owner_identifier=r.owner_identifier,owner_name=r.owner_name,vehicle_model=r.vehicle_model,vehicle_display_name=r.vehicle_display_name,registration={status=r.status,expires_at=r.expires_at,active=STVehicles.IsRegistered(r.plate)},insurance=insurance,title=title,liens=liens,has_active_lien=#liens>0,stolen=#MySQL.query.await("SELECT id FROM st_vehicle_enforcement WHERE vehicle_identifier=? AND event_type='stolen' AND status='active' LIMIT 1",{r.vehicle_identifier})>0,enforcement=enforcement,history=history,mileage=mileage and mileage.mileage or nil}
end
function STMDT.GetDriver(identifier) return STLicenses.Get(identifier) end
function STMDT.GetDriverByLicense(number) return STLicenses.GetByNumber(number) end
exports('GetMDTVehicleRecord',STMDT.GetVehicleByPlate)
exports('GetMDTDriverRecord',STMDT.GetDriver)
exports('GetMDTDriverByLicense',STMDT.GetDriverByLicense)
exports('GetPoliceVehicleRecord',STMDT.GetVehicleByPlate)
exports('GetPoliceDriverRecord',STMDT.GetDriver)
