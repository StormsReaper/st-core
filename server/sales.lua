STSales = {}

local function sendResult(source, ok, message, data)
    TriggerClientEvent('st-core:client:saleContractResult', source, { ok = ok, message = message, data = data })
end
local function normalizeSignature(signature)
    if type(signature) ~= 'string' or #signature < 100 or #signature > 100000 then return nil end
    if not signature:match('^data:image/png;base64,') then return nil end
    return signature
end
local function generateContractNumber()
    for _ = 1, 50 do
        local n = ('ST-DMV-%s-%06d'):format(os.date('%Y%m%d'), math.random(0, 999999))
        if not MySQL.single.await('SELECT id FROM st_vehicle_sale_contracts WHERE contract_number = ? LIMIT 1', { n }) then return n end
    end
end
local function isNear(source, target, maxDistance)
    if not target then return false end
    local a, b = GetPlayerPed(source), GetPlayerPed(target)
    if a <= 0 or b <= 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= (maxDistance or 5.0)
end
local function findClosestVehicle(source, maxDistance)
    local ped = GetPlayerPed(source); if ped <= 0 then return nil end
    local coords, best, bestDistance = GetEntityCoords(ped), nil, nil
    for _, vehicle in ipairs(GetAllVehicles()) do
        local distance = #(coords - GetEntityCoords(vehicle))
        if distance <= (maxDistance or 8.0) and (not bestDistance or distance < bestDistance) then best, bestDistance = vehicle, distance end
    end
    return best
end
local function getContract(id) return MySQL.single.await('SELECT * FROM st_vehicle_sale_contracts WHERE id = ? LIMIT 1', { tonumber(id) }) end
local function audit(actor, id, action, metadata)
    MySQL.insert.await('INSERT INTO st_dmv_document_audit (document_type, document_id, actor_identifier, action, metadata) VALUES (?, ?, ?, ?, ?)', {'vehicle_sale_contract', tostring(id), actor, action, metadata and json.encode(metadata) or nil})
end
local function itemSlot(source, slot, id)
    if GetResourceState('ox_inventory') ~= 'started' then return false, 'ox_inventory_not_started' end
    local item = exports.ox_inventory:GetSlot(source, tonumber(slot))
    if not item or item.name ~= Config.Documents.VehicleSaleContractItem then return false, 'contract_item_not_found' end
    if not item.metadata or tostring(item.metadata.contract_id) ~= tostring(id) then return false, 'contract_item_mismatch' end
    return true, item
end
local function findSourceByIdentifier(identifier)
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        if STPayments.GetIdentifier(src) == identifier then return src end
    end
end
local function contractData(contract, slot)
    return {
        id=contract.id, contractNumber=contract.contract_number, status=contract.status, slot=slot,
        vehicleIdentifier=contract.vehicle_identifier, vin=contract.vin, plate=contract.plate,
        vehicleModel=contract.vehicle_model, vehicleDisplayName=contract.vehicle_display_name,
        sellerName=contract.seller_name, buyerName=contract.buyer_name,
        sellerIdentifier=contract.seller_identifier, buyerIdentifier=contract.buyer_identifier,
        sellerServerId=findSourceByIdentifier(contract.seller_identifier), buyerServerId=findSourceByIdentifier(contract.buyer_identifier),
        salePrice=tonumber(contract.sale_price) or 0, sellerSignature=contract.seller_signature, buyerSignature=contract.buyer_signature,
        sellerSignedAt=contract.seller_signed_at, buyerSignedAt=contract.buyer_signed_at, expiresAt=contract.expires_at,
    }
end

RegisterNetEvent('st-core:server:issueSaleContract', function()
    local source=source; local identifier=STPayments.GetIdentifier(source)
    if not identifier then return sendResult(source,false,'Unable to identify your character.') end
    local coords=GetEntityCoords(GetPlayerPed(source)); local atDMV=false
    for _,loc in ipairs(Config.DMV.Locations or {}) do if #(coords-vector3(loc.x,loc.y,loc.z))<=5.0 then atDMV=true break end end
    if not atDMV then return sendResult(source,false,'You must be at the DMV to request a sale contract.') end
    local number=generateContractNumber(); if not number then return sendResult(source,false,'The DMV contract system is temporarily unavailable.') end
    local now=os.time(); local expires=now+((Config.Documents.ContractValidityDays or 7)*86400)
    local id=MySQL.insert.await([[INSERT INTO st_vehicle_sale_contracts (contract_number,seller_identifier,seller_name,issued_at,expires_at,status,vehicle_identifier,vin,plate,buyer_identifier,buyer_name) VALUES (?,?,?,?,?,'draft','','','','','')]],{number,identifier,STPayments.GetName(source) or 'Unknown',now,expires})
    if not id then return sendResult(source,false,'Unable to issue the sale contract.') end
    local metadata={contract_id=id,contract_number=number,status='draft',description=('DMV Vehicle Sale Contract %s'):format(number)}
    if not exports.ox_inventory:CanCarryItem(source,Config.Documents.VehicleSaleContractItem,1,metadata) then MySQL.update.await("UPDATE st_vehicle_sale_contracts SET status='cancelled' WHERE id=?",{id});return sendResult(source,false,'You do not have room for the sale contract.') end
    if not exports.ox_inventory:AddItem(source,Config.Documents.VehicleSaleContractItem,1,metadata) then MySQL.update.await("UPDATE st_vehicle_sale_contracts SET status='cancelled' WHERE id=?",{id});return sendResult(source,false,'Unable to place the contract in your inventory.') end
    audit(identifier,id,'issued',{contract_number=number});sendResult(source,true,('Sale contract %s issued.'):format(number))
end)

RegisterNetEvent('st-core:server:useSaleContract', function(data)
    local source=source;if type(data)~='table' then return end
    local identifier=STPayments.GetIdentifier(source);local valid,err=itemSlot(source,data.slot,data.contractId);if not valid then return sendResult(source,false,err) end
    local contract=getContract(data.contractId);if not contract then return sendResult(source,false,'This contract no longer exists.') end
    if contract.expires_at<os.time() and contract.status~='completed' then MySQL.update.await("UPDATE st_vehicle_sale_contracts SET status='expired' WHERE id=?",{contract.id});return sendResult(source,false,'This contract has expired.') end
    if contract.status=='draft' then
        if contract.seller_identifier~=identifier then return sendResult(source,false,'Only the seller who requested this contract can start it.') end
        local buyer=tonumber(data.buyerServerId);if not buyer or buyer==source or GetPlayerPed(buyer)<=0 then return sendResult(source,false,'The buyer must be standing nearby.') end
        if not isNear(source,buyer,Config.Sales.BuyerDistance) then return sendResult(source,false,'The buyer must be standing next to you.') end
        local vehicle=findClosestVehicle(source,Config.Sales.VehicleDistance);if not vehicle then return sendResult(source,false,'Stand next to the vehicle you are selling.') end
        local plate=STValidation.NormalizePlate(GetVehicleNumberPlateText(vehicle));local registration=STVehicles.GetRegistrationByPlate(plate)
        if not registration or registration.status~='active' then return sendResult(source,false,'That vehicle does not have an active DMV registration.') end
        if registration.owner_identifier~=identifier then return sendResult(source,false,'That vehicle is not registered to you.') end
        local buyerIdentifier=STPayments.GetIdentifier(buyer);if not buyerIdentifier then return sendResult(source,false,'Unable to identify the buyer.') end
        local buyerName=STPayments.GetName(buyer) or 'Unknown'
        if MySQL.update.await([[UPDATE st_vehicle_sale_contracts SET vehicle_identifier=?,vin=?,plate=?,vehicle_model=?,vehicle_display_name=?,buyer_identifier=?,buyer_name=? WHERE id=? AND status='draft' AND seller_identifier=?]],{registration.vehicle_identifier,registration.vin,registration.plate,registration.vehicle_model,registration.vehicle_display_name or registration.vehicle_model,buyerIdentifier,buyerName,contract.id,identifier})~=1 then return sendResult(source,false,'The contract was already started or changed.') end
        contract=getContract(contract.id)
    end
    if contract.status=='seller_signed' then
        if contract.buyer_identifier~=identifier then return sendResult(source,false,'This contract is assigned to the named buyer.') end
        TriggerClientEvent('st-core:client:saleContract',source,contractData(contract,data.slot));return
    end
    if contract.status=='buyer_signed' then
        if contract.buyer_identifier~=identifier then return sendResult(source,false,'Only the named buyer can submit this contract.') end
        local coords=GetEntityCoords(GetPlayerPed(source));local atDMV=false
        for _,loc in ipairs(Config.DMV.Locations or {}) do if #(coords-vector3(loc.x,loc.y,loc.z))<=5.0 then atDMV=true break end end
        if not atDMV then return sendResult(source,false,'Take the signed contract to the DMV to complete the transfer.') end
        TriggerClientEvent('st-core:client:saleContract',source,contractData(contract,data.slot));return
    end
    if contract.status=='completed' then TriggerClientEvent('st-core:client:saleContract',source,contractData(contract,data.slot));return end
    if contract.seller_identifier==identifier and contract.status=='draft' and contract.vehicle_identifier~='' then TriggerClientEvent('st-core:client:saleContract',source,contractData(contract,data.slot));return end
    sendResult(source,false,'This contract cannot be opened from your inventory.')
end)

RegisterNetEvent('st-core:server:sellerSignSaleContract', function(data)
    local source=source;if type(data)~='table' then return end
    local identifier=STPayments.GetIdentifier(source);local signature=normalizeSignature(data.signature);local price=tonumber(data.salePrice)
    if not signature then return sendResult(source,false,'A valid signature is required.') end
    if not price or price<=0 or price>1000000000 then return sendResult(source,false,'Enter a valid sale price.') end
    local contract=getContract(data.contractId)
    if not contract or contract.status~='draft' or contract.seller_identifier~=identifier then return sendResult(source,false,'This contract is no longer available for seller signature.') end
    if contract.vehicle_identifier=='' or contract.buyer_identifier=='' then return sendResult(source,false,'The vehicle and buyer must be selected first.') end
    if not isNear(source,findSourceByIdentifier(contract.buyer_identifier),Config.Sales.BuyerDistance) then return sendResult(source,false,'The buyer must remain nearby while signing.') end
    local registration=STVehicles.GetRegistration(contract.vehicle_identifier)
    if not registration or registration.owner_identifier~=identifier or registration.plate~=contract.plate then return sendResult(source,false,'Vehicle ownership changed before signing.') end
    if MySQL.update.await("UPDATE st_vehicle_sale_contracts SET sale_price=?,seller_signature=?,seller_signed_at=?,status='seller_signed' WHERE id=? AND status='draft' AND seller_identifier=?",{price,signature,os.time(),contract.id,identifier})~=1 then return sendResult(source,false,'Unable to sign the contract.') end
    audit(identifier,contract.id,'seller_signed',{sale_price=price})
    local ok,item=itemSlot(source,data.slot,contract.id)
    if ok then item.metadata.status='seller_signed';item.metadata.vehicle_plate=contract.plate;item.metadata.buyer_name=contract.buyer_name;item.metadata.sale_price=price;item.metadata.description=('SIGNED SALE CONTRACT %s | %s | $%s'):format(contract.contract_number,contract.plate,price);exports.ox_inventory:SetMetadata(source,tonumber(data.slot),item.metadata) end
    TriggerClientEvent('st-core:client:saleContract',source,contractData(getContract(contract.id),data.slot))
end)

RegisterNetEvent('st-core:server:buyerSignSaleContract', function(data)
    local source=source;if type(data)~='table' then return end
    local identifier=STPayments.GetIdentifier(source);local signature=normalizeSignature(data.signature);if not signature then return sendResult(source,false,'A valid buyer signature is required.') end
    local contract=getContract(data.contractId)
    if not contract or contract.status~='seller_signed' then return sendResult(source,false,'This contract is not awaiting buyer signature.') end
    if contract.buyer_identifier~=identifier then return sendResult(source,false,'You are not the buyer named on this contract.') end
    if contract.expires_at<os.time() then return sendResult(source,false,'This contract has expired.') end
    local sellerSource=findSourceByIdentifier(contract.seller_identifier);if not sellerSource or not isNear(source,sellerSource,Config.Sales.BuyerDistance) then return sendResult(source,false,'The seller must remain nearby while you sign.') end
    local registration=STVehicles.GetRegistration(contract.vehicle_identifier)
    if not registration or registration.owner_identifier~=contract.seller_identifier or registration.plate~=contract.plate then return sendResult(source,false,'The vehicle is no longer owned by the seller.') end
    if Config.Sales.RequireSameVehicleAtFinalization then local vehicle=findClosestVehicle(source,Config.Sales.VehicleDistance);if not vehicle or STValidation.NormalizePlate(GetVehicleNumberPlateText(vehicle))~=contract.plate then return sendResult(source,false,'The vehicle must be nearby when the buyer signs.') end end
    if MySQL.update.await("UPDATE st_vehicle_sale_contracts SET buyer_signature=?,buyer_signed_at=?,status='buyer_signed' WHERE id=? AND status='seller_signed' AND buyer_identifier=?",{signature,os.time(),contract.id,identifier})~=1 then return sendResult(source,false,'Unable to record the buyer signature.') end
    audit(identifier,contract.id,'buyer_signed',{sale_price=contract.sale_price})
    local ok,item=itemSlot(source,data.slot,contract.id)
    if ok then item.metadata.status='buyer_signed';item.metadata.description=('SIGNED BUYER CONTRACT %s | %s | $%s'):format(contract.contract_number,contract.plate,contract.sale_price);exports.ox_inventory:SetMetadata(source,tonumber(data.slot),item.metadata) end
    TriggerClientEvent('st-core:client:saleContract',source,contractData(getContract(contract.id),data.slot))
end)

RegisterNetEvent('st-core:server:submitSaleContract', function(data)
    local source=source;if type(data)~='table' then return end
    local identifier=STPayments.GetIdentifier(source);local contract=getContract(data.contractId)
    if not contract or contract.status~='buyer_signed' then return sendResult(source,false,'This contract is not ready for DMV submission.') end
    if contract.buyer_identifier~=identifier then return sendResult(source,false,'Only the named buyer can submit this contract.') end
    local coords=GetEntityCoords(GetPlayerPed(source));local atDMV=false
    for _,loc in ipairs(Config.DMV.Locations or {}) do if #(coords-vector3(loc.x,loc.y,loc.z))<=5.0 then atDMV=true break end end
    if not atDMV then return sendResult(source,false,'You must be at the DMV to submit the contract.') end
    local registration=STVehicles.GetRegistration(contract.vehicle_identifier)
    if not registration or registration.owner_identifier~=contract.seller_identifier or registration.plate~=contract.plate then return sendResult(source,false,'The seller no longer owns this vehicle. Transfer cancelled.') end
    local fee=tonumber(Config.Registration.TransferFee) or 0;local paid,err=STPayments.Charge(source,fee,'DMV vehicle ownership transfer')
    if not paid then return sendResult(source,false,err=='insufficient_funds' and 'Insufficient funds for the DMV transfer fee.' or 'Transfer payment failed.') end
    local framework=GetResourceState('qb-core')=='started' and 'qbcore' or (GetResourceState('es_extended')=='started' and 'esx' or nil)
    if not framework then STPayments.Add(source,fee,'bank','DMV transfer refund');return sendResult(source,false,'Unsupported framework; transfer cancelled.') end
    local now=os.time();local expires=now+((Config.Registration.DurationDays or 30)*86400)
    local ownerQuery=framework=='qbcore' and 'UPDATE player_vehicles SET citizenid=? WHERE citizenid=? AND plate=?' or 'UPDATE owned_vehicles SET owner=? WHERE owner=? AND plate=?'
    local tx={
        {ownerQuery,{identifier,contract.seller_identifier,contract.plate}},
        {"UPDATE st_vehicle_registrations SET owner_identifier=?,owner_name=?,registered_at=?,expires_at=?,status='active',updated_at=CURRENT_TIMESTAMP WHERE id=? AND owner_identifier=?",{identifier,contract.buyer_name,now,expires,registration.id,contract.seller_identifier}},
        {"UPDATE st_vehicle_records SET owner_identifier=?,owner_name=?,registration_status='active',registration_expires_at=?,updated_at=CURRENT_TIMESTAMP WHERE vehicle_identifier=? AND owner_identifier=?",{identifier,contract.buyer_name,expires,contract.vehicle_identifier,contract.seller_identifier}},
        {"UPDATE st_vehicle_insurance SET status='cancelled',cancellation_reason='Vehicle transferred to new owner',updated_at=CURRENT_TIMESTAMP WHERE vehicle_identifier=? AND owner_identifier=? AND status='active'",{contract.vehicle_identifier,contract.seller_identifier}},
        {'INSERT INTO st_vehicle_transfer_audit (contract_id,vehicle_identifier,vin,old_owner_identifier,old_owner_name,new_owner_identifier,new_owner_name,sale_price,old_plate,new_plate,transferred_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',{contract.id,contract.vehicle_identifier,contract.vin,contract.seller_identifier,contract.seller_name,identifier,contract.buyer_name,contract.sale_price,contract.plate,contract.plate,now}},
        {"UPDATE st_vehicle_sale_contracts SET status='completed',completed_at=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND status='buyer_signed'",{now,contract.id}},
    }
    if not MySQL.transaction.await(tx) then STPayments.Add(source,fee,'bank','DMV transfer refund');return sendResult(source,false,'The ownership transfer could not be completed. No ownership was changed.') end
    audit(identifier,contract.id,'dmv_transfer_completed',{sale_price=contract.sale_price,fee=fee})
    local ok=itemSlot(source,data.slot,contract.id);if ok then exports.ox_inventory:RemoveItem(source,Config.Documents.VehicleSaleContractItem,1,nil,tonumber(data.slot),true) end
    local completed=getContract(contract.id);TriggerClientEvent('st-core:client:saleContract',source,contractData(completed,nil));sendResult(source,true,('Ownership transferred and new registration issued. DMV fee: $%s'):format(fee),contractData(completed))
end)

CreateThread(function()
    while true do Wait(300000);if Config.Sales.AutoCancelExpiredContracts then MySQL.update.await("UPDATE st_vehicle_sale_contracts SET status='expired',updated_at=CURRENT_TIMESTAMP WHERE status IN ('draft','seller_signed','buyer_signed') AND expires_at<?",{os.time()}) end end
end)
exports('GetVehicleSaleContract',getContract)
