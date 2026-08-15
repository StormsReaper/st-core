STEnforcement = {}
function STEnforcement.Add(data)
    local id=MySQL.insert.await('INSERT INTO st_vehicle_enforcement (vehicle_identifier,plate,event_type,status,officer_identifier,notes) VALUES (?,?,?,?,?,?)',{data.vehicleIdentifier,data.plate,data.eventType or 'notice','active',data.officerIdentifier,data.notes})
    if id then STVehicleHistory.Add(data.vehicleIdentifier,data.eventType or 'enforcement',{actorIdentifier=data.officerIdentifier,details=data}) end
    return id ~= nil,id
end
function STEnforcement.Resolve(id) return MySQL.update.await("UPDATE st_vehicle_enforcement SET status='resolved',resolved_at=? WHERE id=? AND status='active'",{os.time(),id})==1 end
function STEnforcement.GetVehicle(vehicleIdentifier) return MySQL.query.await("SELECT * FROM st_vehicle_enforcement WHERE vehicle_identifier=? ORDER BY created_at DESC",{vehicleIdentifier}) end
function STEnforcement.GetByPlate(plate) return MySQL.query.await("SELECT * FROM st_vehicle_enforcement WHERE plate=? ORDER BY created_at DESC",{STValidation.NormalizePlate(plate)}) end
function STEnforcement.SetRegistrationSuspended(vehicleIdentifier,reason,officer) local ok=MySQL.update.await("UPDATE st_vehicle_registrations SET status='suspended',updated_at=CURRENT_TIMESTAMP WHERE vehicle_identifier=?",{vehicleIdentifier})==1; if ok then STEnforcement.Add({vehicleIdentifier=vehicleIdentifier,plate=(STVehicles.GetRegistration(vehicleIdentifier) or {}).plate,eventType='registration_suspension',officerIdentifier=officer,notes=reason}); STVehicles.SyncVehicleRecord(vehicleIdentifier) end return ok end
exports('AddVehicleEnforcement',STEnforcement.Add); exports('ResolveVehicleEnforcement',STEnforcement.Resolve); exports('GetVehicleEnforcement',STEnforcement.GetVehicle); exports('GetVehicleEnforcementByPlate',STEnforcement.GetByPlate); exports('SuspendVehicleRegistration',STEnforcement.SetRegistrationSuspended)
