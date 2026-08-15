local function result(ok, message, data) return { ok=ok, message=message, data=data } end
local function notify(source,payload) TriggerClientEvent('st-core:client:dmvResult',source,payload) end
local function syncFrameworkPlate(ownerIdentifier,oldPlate,newPlate) if not oldPlate or oldPlate==newPlate then return true end return STVehicles.UpdateOwnedVehiclePlate(ownerIdentifier,oldPlate,newPlate) end
RegisterNetEvent('st-core:server:dmvOpen',function() TriggerEvent('st-core:server:dmvData',source) end)
RegisterNetEvent('st-core:server:dmvData',function(targetSource)
 local source=targetSource or source; local identifier=STPayments.GetIdentifier(source); if not identifier then return notify(source,result(false,'Unable to identify your character.')) end
 local pending={}; if STPurchases and STPurchases.GetPending then pending=STPurchases.GetPending(source) or {} end
 local registrations=MySQL.query.await('SELECT * FROM st_vehicle_registrations WHERE owner_identifier = ? ORDER BY updated_at DESC',{identifier}) or {}
 local policies=MySQL.query.await([[SELECT i.*,p.name AS plan_name,p.description AS plan_description,p.coverage_type,p.liability_limit,p.collision_limit,p.comprehensive_limit,p.deductible,r.plate FROM st_vehicle_insurance i LEFT JOIN st_insurance_plans p ON p.id=i.plan_id LEFT JOIN st_vehicle_registrations r ON r.vehicle_identifier=i.vehicle_identifier WHERE i.owner_identifier=? ORDER BY i.updated_at DESC]],{identifier}) or {}
 TriggerClientEvent('st-core:client:dmvData',source,{pendingPurchases=pending,registrations=registrations,insurance=policies,plans=STInsurance.GetPlans(),fees={customPlate=Config.Plate.CustomPlateFee,registration=Config.Payment.RegistrationFee,transfer=Config.Registration.TransferFee}})
end)
RegisterNetEvent('st-core:server:lookupVehicleByPlate',function(data)
 local source=source; if type(data)~='table' then return notify(source,result(false,'Invalid request.')) end; local identifier=STPayments.GetIdentifier(source); if not identifier then return notify(source,result(false,'Unable to identify your character.')) end
 local plate=STValidation.NormalizePlate(data.plate); if plate=='' then return notify(source,result(false,'Enter the vehicle plate number.')) end
 local lookup,err=STVehicles.LookupOwnedVehicleForDMV(identifier,STPayments.GetName(source),plate); if not lookup then return notify(source,result(false,err=='vehicle_not_found_or_not_owned' and 'No vehicle with that plate is registered to your character.' or 'Unable to look up that plate.')) end
 if lookup.alreadyRegistered then return notify(source,result(true,'This vehicle is already registered.',{lookup=lookup})) end
 notify(source,result(true,'Vehicle found. Review the information before registering it.',{lookup=lookup}))
end)
RegisterNetEvent('st-core:server:registerVehicle',function(data)
 local source=source; if type(data)~='table' then return notify(source,result(false,'Invalid request.')) end; local identifier=STPayments.GetIdentifier(source); if not identifier then return notify(source,result(false,'Unable to identify your character.')) end
 local enteredPlate=STValidation.NormalizePlate(data.lookupPlate or data.plateNumber or ''); if enteredPlate=='' then return notify(source,result(false,'Enter the vehicle plate number first.')) end
 local vehicle,lookupError=STVehicles.LookupOwnedVehicleForDMV(identifier,STPayments.GetName(source),enteredPlate); if not vehicle then return notify(source,result(false,lookupError=='vehicle_not_found_or_not_owned' and 'Vehicle not found or you are not the owner.' or 'Vehicle lookup failed.')) end
 if vehicle.alreadyRegistered then return notify(source,result(false,'This vehicle is already registered.')) end
 local fee=tonumber(Config.Payment.RegistrationFee) or 0; local customPlate=data.customPlate and STValidation.NormalizePlate(data.customPlate) or nil; local customFee=customPlate and tonumber(Config.Plate.CustomPlateFee) or 0; local total=fee+customFee
 if customPlate and not STValidation.IsCustomPlate(customPlate) then return notify(source,result(false,'Invalid custom plate.')) end
 local paid,paymentAccountOrError=STPayments.Charge(source,total,'DMV vehicle registration'); if not paid then return notify(source,result(false,paymentAccountOrError=='insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
 local ok,registration=STVehicles.RegisterVehicle({vehicleIdentifier=vehicle.vehicleIdentifier,ownerIdentifier=identifier,ownerName=STPayments.GetName(source),vehicleModel=vehicle.model,vehicleDisplayName=vehicle.displayName,purchasePrice=vehicle.purchasePrice,purchaseType=vehicle.purchaseType,paymentMethod=vehicle.paymentMethod,financed=vehicle.financed,dealership=vehicle.dealership,plate=customPlate})
 if not ok then STPayments.Add(source,total,paymentAccountOrError or 'bank','DMV registration refund'); return notify(source,result(false,registration)) end
 local synced=syncFrameworkPlate(identifier,enteredPlate,registration.plate); if not synced then MySQL.query.await('DELETE FROM st_vehicle_registrations WHERE id=?',{registration.id}); STPayments.Add(source,total,paymentAccountOrError or 'bank','DMV registration refund'); return notify(source,result(false,'The framework vehicle plate could not be updated; registration was rolled back.')) end
 if STPurchases and STPurchases.MarkRegistered then STPurchases.MarkRegistered(vehicle.vehicleIdentifier,enteredPlate,identifier) end
 STVehicles.SyncVehicleRecord(vehicle.vehicleIdentifier)
 local titleOk=STTitles and STTitles.Issue and STTitles.Issue(vehicle.vehicleIdentifier,identifier,STPayments.GetName(source),vehicle.financed and 'lien' or 'clear')
 local documentOk=STDocuments and STDocuments.CreateRegistrationDocument and STDocuments.CreateRegistrationDocument(source,STVehicles.GetRegistration(vehicle.vehicleIdentifier))
 notify(source,result(true,('Vehicle registered successfully. Plate: %s. Total paid: $%s%s'):format(registration.plate,total,titleOk and '' or ' (title issuance pending)'),STVehicles.GetRegistration(vehicle.vehicleIdentifier)))
 TriggerClientEvent('st-core:client:dmvData',source,{refresh=true,documentIssued=documentOk and true or false})
end)
RegisterNetEvent('st-core:server:renewRegistration',function(data)
 local source=source; local identifier=STPayments.GetIdentifier(source); local registration=STVehicles.GetRegistration(data and data.vehicleIdentifier); if not registration or registration.owner_identifier~=identifier then return notify(source,result(false,'Registration not found.')) end
 local fee=tonumber(Config.Payment.RegistrationRenewalFee) or Config.Payment.RegistrationFee or 0; local paid,paymentAccountOrError=STPayments.Charge(source,fee,'DMV registration renewal'); if not paid then return notify(source,result(false,paymentAccountOrError=='insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
 local ok,renewed=STVehicles.RenewRegistration(registration.vehicle_identifier); if not ok then STPayments.Add(source,fee,paymentAccountOrError or 'bank','DMV renewal refund'); return notify(source,result(false,renewed)) end
 local cardOk=STDocuments and STDocuments.CreateRegistrationDocument and STDocuments.CreateRegistrationDocument(source,renewed); notify(source,result(true,cardOk and 'Registration renewed and document issued.' or 'Registration renewed.',renewed))
end)
RegisterNetEvent('st-core:server:buyInsurance',function(data)
 local source=source; local identifier=STPayments.GetIdentifier(source); local vehicle=STVehicles.GetRegistration(data and data.vehicleIdentifier); if not vehicle or vehicle.owner_identifier~=identifier then return notify(source,result(false,'Vehicle registration not found.')) end
 local plan=STInsurance.GetPlan(data.planId); if not plan then return notify(source,result(false,'Insurance plan not found.')) end
 local paid,paymentAccountOrError=STPayments.Charge(source,plan.monthly_premium,'Vehicle insurance premium'); if not paid then return notify(source,result(false,paymentAccountOrError=='insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
 local ok,policy=STInsurance.PurchasePolicy({ownerIdentifier=identifier,vehicleIdentifier=vehicle.vehicle_identifier,planId=plan.id}); if not ok then STPayments.Add(source,plan.monthly_premium,paymentAccountOrError or 'bank','Insurance purchase refund'); return notify(source,result(false,policy)) end
 policy.plate=vehicle.plate; policy.insured_name=vehicle.owner_name; local cardOk,cardError=STDocuments.CreateInsuranceCard(source,policy); STVehicles.SyncVehicleRecord(vehicle.vehicle_identifier)
 notify(source,result(true,cardOk and 'Insurance purchased and card issued.' or ('Insurance purchased, but card could not be issued: '..tostring(cardError)),policy))
end)
RegisterNetEvent('st-core:server:renewInsurance',function(data)
 local source=source; local identifier=STPayments.GetIdentifier(source); local policy=STInsurance.GetPolicy(data and data.vehicleIdentifier); if not policy or policy.owner_identifier~=identifier then return notify(source,result(false,'Insurance policy not found.')) end
 local paid,paymentAccountOrError=STPayments.Charge(source,policy.premium,'Vehicle insurance renewal'); if not paid then return notify(source,result(false,paymentAccountOrError=='insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
 local ok,renewed=STInsurance.RenewPolicy(policy.vehicle_identifier); if not ok then STPayments.Add(source,policy.premium,paymentAccountOrError or 'bank','Insurance renewal refund'); return notify(source,result(false,renewed)) end
 renewed.plate=policy.plate; renewed.insured_name=policy.insured_name or STPayments.GetName(source); local cardOk=STDocuments.CreateInsuranceCard(source,renewed); STVehicles.SyncVehicleRecord(policy.vehicle_identifier); notify(source,result(true,cardOk and 'Insurance renewed and new card issued.' or 'Insurance renewed.',renewed))
end)
RegisterNetEvent('st-core:server:customPlate',function(data)
 local source=source; local identifier=STPayments.GetIdentifier(source); local registration=STVehicles.GetRegistration(data and data.vehicleIdentifier); if not registration or registration.owner_identifier~=identifier then return notify(source,result(false,'Registration not found.')) end
 local plate=STValidation.NormalizePlate(data.plate); if not STValidation.IsCustomPlate(plate) then return notify(source,result(false,'Invalid custom plate.')) end
 local fee=tonumber(Config.Plate.CustomPlateFee) or 0; local paid,paymentAccountOrError=STPayments.Charge(source,fee,'Custom vehicle plate'); if not paid then return notify(source,result(false,paymentAccountOrError=='insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
 local oldPlate=registration.plate; local synced,syncError=STVehicles.UpdateOwnedVehiclePlate(identifier,oldPlate,plate); if not synced then STPayments.Add(source,fee,paymentAccountOrError or 'bank','Custom plate refund'); return notify(source,result(false,syncError or 'Unable to update vehicle plate.')) end
 if MySQL.update.await("UPDATE st_vehicle_registrations SET plate=?,plate_type='custom',updated_at=CURRENT_TIMESTAMP WHERE id=?",{plate,registration.id})~=1 then STVehicles.UpdateOwnedVehiclePlate(identifier,plate,oldPlate); STPayments.Add(source,fee,paymentAccountOrError or 'bank','Custom plate refund'); return notify(source,result(false,'Unable to update registration.')) end
 STVehicles.SyncVehicleRecord(registration.vehicle_identifier); notify(source,result(true,'Custom plate assigned.',STVehicles.GetRegistration(registration.vehicle_identifier)))
end)
