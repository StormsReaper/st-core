STVehicleHistory = {}
local function validVehicle(id) return STValidation.IsIdentifier(id) end
function STVehicleHistory.Add(vehicleIdentifier, eventType, data)
    if not validVehicle(vehicleIdentifier) or type(eventType) ~= 'string' then return false end
    data = data or {}
    return MySQL.insert.await([[INSERT INTO st_vehicle_history (vehicle_identifier,event_type,actor_identifier,actor_name,old_owner_identifier,old_owner_name,new_owner_identifier,new_owner_name,old_plate,new_plate,details,occurred_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)]], {vehicleIdentifier,eventType,data.actorIdentifier,data.actorName,data.oldOwnerIdentifier,data.oldOwnerName,data.newOwnerIdentifier,data.newOwnerName,data.oldPlate,data.newPlate,type(data.details)=='table' and json.encode(data.details) or data.details,os.time()}) ~= nil
end
function STVehicleHistory.Get(vehicleIdentifier, limit)
    if not validVehicle(vehicleIdentifier) then return {} end
    limit = math.min(tonumber(limit) or 50, 200)
    return MySQL.query.await(('SELECT * FROM st_vehicle_history WHERE vehicle_identifier = ? ORDER BY occurred_at DESC LIMIT %d'):format(limit), {vehicleIdentifier})
end
function STVehicleHistory.GetByPlate(plate, limit)
    local registration = STVehicles.GetRegistrationByPlate(plate)
    return registration and STVehicleHistory.Get(registration.vehicle_identifier, limit) or {}
end
exports('AddVehicleHistory', STVehicleHistory.Add)
exports('GetVehicleHistory', STVehicleHistory.Get)
exports('GetVehicleHistoryByPlate', STVehicleHistory.GetByPlate)
function STVehicleHistory.RecordOwnershipTransfer(vehicleIdentifier, oldOwner, oldName, newOwner, newName, oldPlate, newPlate, actor)
    return STVehicleHistory.Add(vehicleIdentifier,'ownership_transfer',{oldOwnerIdentifier=oldOwner,oldOwnerName=oldName,newOwnerIdentifier=newOwner,newOwnerName=newName,oldPlate=oldPlate,newPlate=newPlate,actorIdentifier=actor,actorName=newName})
end
