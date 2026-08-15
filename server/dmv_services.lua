STDMVServices = {}
local function number(prefix) for _=1,50 do local n=('%s-%08d'):format(prefix,math.random(0,99999999)); local tableName=prefix=='DMV' and 'st_dmv_appointments' or nil; if not tableName or not MySQL.single.await('SELECT id FROM '..tableName..' WHERE appointment_number=? LIMIT 1',{n}) then return n end end end
function STDMVServices.BookAppointment(data)
    local n=number('DMV'); if not n then return false,'number_generation_failed' end
    local id=MySQL.insert.await('INSERT INTO st_dmv_appointments (appointment_number,owner_identifier,owner_name,appointment_type,scheduled_at) VALUES (?,?,?,?,?)',{n,data.ownerIdentifier,data.ownerName or 'Unknown',data.appointmentType or 'general',tonumber(data.scheduledAt) or os.time()})
    return id ~= nil,id and MySQL.single.await('SELECT * FROM st_dmv_appointments WHERE id=?',{id}) or 'database_insert_failed'
end
function STDMVServices.GetAppointments(identifier) return MySQL.query.await('SELECT * FROM st_dmv_appointments WHERE owner_identifier=? ORDER BY scheduled_at DESC',{identifier}) end
function STDMVServices.CancelAppointment(id) return MySQL.update.await("UPDATE st_dmv_appointments SET status='cancelled' WHERE id=? AND status='scheduled'",{id})==1 end
function STDMVServices.RecordMileage(vehicleIdentifier,mileage,source,actor) return MySQL.insert.await('INSERT INTO st_vehicle_mileage (vehicle_identifier,mileage,source,recorded_by) VALUES (?,?,?,?)',{vehicleIdentifier,tonumber(mileage) or 0,source or 'manual',actor}) ~= nil end
function STDMVServices.GetMileage(vehicleIdentifier) return MySQL.single.await('SELECT mileage FROM st_vehicle_mileage WHERE vehicle_identifier=? ORDER BY id DESC LIMIT 1',{vehicleIdentifier}) end
function STDMVServices.ReportAccident(data)
    local n; for _=1,50 do n=('ACC-%08d'):format(math.random(0,99999999)); if not MySQL.single.await('SELECT id FROM st_vehicle_accidents WHERE accident_number=?',{n}) then break end end
    local id=MySQL.insert.await('INSERT INTO st_vehicle_accidents (accident_number,vehicle_identifier,plate,reported_by,damage_estimate,fault_percent,description) VALUES (?,?,?,?,?,?,?)',{n,data.vehicleIdentifier,data.plate,data.reportedBy,tonumber(data.damageEstimate) or 0,tonumber(data.faultPercent) or 0,data.description})
    if id then STVehicleHistory.Add(data.vehicleIdentifier,'accident',{actorIdentifier=data.reportedBy,details=data}) end
    return id ~= nil,id and n or 'database_insert_failed'
end
exports('BookDMVAppointment',STDMVServices.BookAppointment); exports('GetDMVAppointments',STDMVServices.GetAppointments); exports('CancelDMVAppointment',STDMVServices.CancelAppointment); exports('RecordVehicleMileage',STDMVServices.RecordMileage); exports('GetVehicleMileage',STDMVServices.GetMileage); exports('ReportVehicleAccident',STDMVServices.ReportAccident)
