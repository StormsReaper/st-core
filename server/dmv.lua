local function result(ok, message, data) return { ok = ok, message = message, data = data } end
local function notify(source, payload) TriggerClientEvent('st-core:client:dmvResult', source, payload) end

local function getPurchaseOriginalPlate(purchase)
    if not purchase or type(purchase.vehicle_identifier) ~= 'string' then return nil end
    local prefix = Config.Integrations and Config.Integrations.JGDealershipsV2 and Config.Integrations.JGDealershipsV2.IdentifierPrefix or 'jg:'
    if purchase.vehicle_identifier:sub(1, #prefix) ~= prefix then return nil end
    return purchase.vehicle_identifier:sub(#prefix + 1)
end

local function syncFrameworkPlate(ownerIdentifier, oldPlate, newPlate)
    if not oldPlate or oldPlate == newPlate then return true end
    return STVehicles.UpdateOwnedVehiclePlate(ownerIdentifier, oldPlate, newPlate)
end

RegisterNetEvent('st-core:server:dmvOpen', function()
    local source = source
    TriggerEvent('st-core:server:dmvData', source)
end)

RegisterNetEvent('st-core:server:dmvData', function(targetSource)
    local source = targetSource or source
    local identifier = STPayments.GetIdentifier(source)
    if not identifier then return notify(source, result(false, 'Unable to identify your character.')) end

    local pending = STPurchases.GetPending(source)
    local registrations = MySQL.query.await('SELECT * FROM st_vehicle_registrations WHERE owner_identifier = ? ORDER BY updated_at DESC', { identifier }) or {}
    local policies = MySQL.query.await([[SELECT i.*, p.name AS plan_name, p.description AS plan_description, p.coverage_type,
        p.liability_limit, p.collision_limit, p.comprehensive_limit, p.deductible, r.plate
        FROM st_vehicle_insurance i LEFT JOIN st_insurance_plans p ON p.id = i.plan_id
        LEFT JOIN st_vehicle_registrations r ON r.vehicle_identifier = i.vehicle_identifier
        WHERE i.owner_identifier = ? ORDER BY i.updated_at DESC]], { identifier }) or {}

    TriggerClientEvent('st-core:client:dmvData', source, {
        pendingPurchases = pending,
        registrations = registrations,
        insurance = policies,
        plans = STInsurance.GetPlans(),
        fees = { customPlate = Config.Plate.CustomPlateFee, registration = Config.Payment.RegistrationFee }
    })
end)

RegisterNetEvent('st-core:server:registerVehicle', function(data)
    local source = source
    if type(data) ~= 'table' then return notify(source, result(false, 'Invalid request.')) end
    local purchase = STPurchases.GetPurchase(data.vehicleIdentifier)
    local identifier = STPayments.GetIdentifier(source)
    if not purchase or purchase.status ~= 'pending' then return notify(source, result(false, 'Vehicle is not awaiting registration.')) end
    if purchase.owner_identifier ~= identifier then return notify(source, result(false, 'You are not the registered purchaser.')) end

    local registrationFee = tonumber(Config.Payment.RegistrationFee) or 0
    local customFee = data.customPlate and tonumber(Config.Plate.CustomPlateFee) or 0
    local total = registrationFee + customFee
    local paid, payError = STPayments.Charge(source, total, 'DMV vehicle registration')
    if not paid then return notify(source, result(false, payError == 'insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end

    local requestedPlate = data.customPlate and STValidation.NormalizePlate(data.customPlate) or nil
    local oldPlate = getPurchaseOriginalPlate(purchase)
    local synced = syncFrameworkPlate(identifier, oldPlate, requestedPlate or '')
    if not synced then
        STPayments.Add(source, total, 'bank', 'DMV registration refund')
        return notify(source, result(false, 'The vehicle record could not be updated. Registration was not completed.'))
    end

    local ok, registration = STVehicles.RegisterVehicle({ ownerIdentifier = identifier, vehicleIdentifier = purchase.vehicle_identifier, plate = requestedPlate })
    if not ok then
        if requestedPlate then STVehicles.UpdateOwnedVehiclePlate(identifier, requestedPlate, oldPlate) end
        STPayments.Add(source, total, 'bank', 'DMV registration refund')
        return notify(source, result(false, registration))
    end

    STPurchases.MarkRegistered(purchase.vehicle_identifier)
    notify(source, result(true, ('Vehicle registered successfully. Total paid: $%s'):format(total), registration))
    TriggerClientEvent('st-core:client:dmvData', source, { refresh = true })
end)

RegisterNetEvent('st-core:server:renewRegistration', function(data)
    local source = source
    local identifier = STPayments.GetIdentifier(source)
    local registration = STVehicles.GetRegistration(data and data.vehicleIdentifier)
    if not registration or registration.owner_identifier ~= identifier then return notify(source, result(false, 'Registration not found.')) end

    local fee = tonumber(Config.Payment.RegistrationRenewalFee) or Config.Payment.RegistrationFee or 0
    local paid, err = STPayments.Charge(source, fee, 'DMV registration renewal')
    if not paid then return notify(source, result(false, err == 'insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
    local ok, renewed = STVehicles.RenewRegistration(registration.vehicle_identifier)
    if not ok then STPayments.Add(source, fee, 'bank', 'DMV renewal refund'); return notify(source, result(false, renewed)) end
    notify(source, result(true, 'Registration renewed.', renewed))
end)

RegisterNetEvent('st-core:server:buyInsurance', function(data)
    local source = source
    local identifier = STPayments.GetIdentifier(source)
    local vehicle = STVehicles.GetRegistration(data and data.vehicleIdentifier)
    if not vehicle or vehicle.owner_identifier ~= identifier then return notify(source, result(false, 'Vehicle registration not found.')) end
    local plan = STInsurance.GetPlan(data.planId)
    if not plan then return notify(source, result(false, 'Insurance plan not found.')) end

    local paid, err = STPayments.Charge(source, plan.monthly_premium, 'Vehicle insurance premium')
    if not paid then return notify(source, result(false, err == 'insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
    local ok, policy = STInsurance.PurchasePolicy({ ownerIdentifier = identifier, vehicleIdentifier = vehicle.vehicle_identifier, planId = plan.id })
    if not ok then STPayments.Add(source, plan.monthly_premium, 'bank', 'Insurance purchase refund'); return notify(source, result(false, policy)) end

    policy.plate = vehicle.plate
    local cardOk, cardError = STDocuments.CreateInsuranceCard(source, policy)
    notify(source, result(true, cardOk and 'Insurance purchased and card issued.' or ('Insurance purchased, but card could not be issued: ' .. tostring(cardError)), policy))
end)

RegisterNetEvent('st-core:server:renewInsurance', function(data)
    local source = source
    local identifier = STPayments.GetIdentifier(source)
    local policy = STInsurance.GetPolicy(data and data.vehicleIdentifier)
    if not policy or policy.owner_identifier ~= identifier then return notify(source, result(false, 'Insurance policy not found.')) end

    local paid, err = STPayments.Charge(source, policy.premium, 'Vehicle insurance renewal')
    if not paid then return notify(source, result(false, err == 'insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end
    local ok, renewed = STInsurance.RenewPolicy(policy.vehicle_identifier)
    if not ok then STPayments.Add(source, policy.premium, 'bank', 'Insurance renewal refund'); return notify(source, result(false, renewed)) end

    renewed.plate = policy.plate
    local cardOk = STDocuments.CreateInsuranceCard(source, renewed)
    notify(source, result(true, cardOk and 'Insurance renewed and new card issued.' or 'Insurance renewed.', renewed))
end)

RegisterNetEvent('st-core:server:customPlate', function(data)
    local source = source
    local identifier = STPayments.GetIdentifier(source)
    local registration = STVehicles.GetRegistration(data and data.vehicleIdentifier)
    if not registration or registration.owner_identifier ~= identifier then return notify(source, result(false, 'Registration not found.')) end
    local plate = STValidation.NormalizePlate(data.plate)
    if not STValidation.IsCustomPlate(plate) then return notify(source, result(false, 'Invalid custom plate.')) end
    if MySQL.single.await('SELECT id FROM st_vehicle_registrations WHERE plate = ? LIMIT 1', { plate }) then return notify(source, result(false, 'That plate is already in use.')) end

    local fee = tonumber(Config.Plate.CustomPlateFee) or 0
    local paid, err = STPayments.Charge(source, fee, 'Custom vehicle plate')
    if not paid then return notify(source, result(false, err == 'insufficient_funds' and 'Insufficient funds.' or 'Payment failed.')) end

    local oldPlate = registration.plate
    local synced, syncError = STVehicles.UpdateOwnedVehiclePlate(identifier, oldPlate, plate)
    if not synced then
        STPayments.Add(source, fee, 'bank', 'Custom plate refund')
        return notify(source, result(false, syncError or 'Unable to update vehicle plate.'))
    end

    local affected = MySQL.update.await("UPDATE st_vehicle_registrations SET plate = ?, plate_type = 'custom', updated_at = CURRENT_TIMESTAMP WHERE id = ?", { plate, registration.id })
    if affected ~= 1 then
        STVehicles.UpdateOwnedVehiclePlate(identifier, plate, oldPlate)
        STPayments.Add(source, fee, 'bank', 'Custom plate refund')
        return notify(source, result(false, 'Unable to update registration.'))
    end
    notify(source, result(true, 'Custom plate assigned.', STVehicles.GetRegistration(registration.vehicle_identifier)))
end)
