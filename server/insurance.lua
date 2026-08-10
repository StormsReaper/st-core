STInsurance = {}

local function generatePolicyNumber()
    for _ = 1, (Config.Insurance.PolicyGenerationAttempts or 50) do
        local policy = ('%s-%06d'):format(
            Config.Insurance.PolicyPrefix or 'STI',
            math.random(0, 999999)
        )

        local exists = MySQL.single.await(
            'SELECT id FROM st_vehicle_insurance WHERE policy_number = ? LIMIT 1',
            { policy }
        )

        if not exists then
            return policy
        end
    end

    return nil
end

local function getPlan(planId)
    if not planId then
        return nil
    end

    return MySQL.single.await(
        'SELECT * FROM st_insurance_plans WHERE id = ? AND active = 1 LIMIT 1',
        { planId }
    )
end

function STInsurance.GetPlan(planId)
    return getPlan(planId)
end

function STInsurance.GetPlans()
    return MySQL.query.await(
        'SELECT * FROM st_insurance_plans WHERE active = 1 ORDER BY monthly_premium ASC'
    )
end

function STInsurance.GetPolicy(vehicleIdentifier)
    if not STValidation.IsIdentifier(vehicleIdentifier) then
        return nil
    end

    return MySQL.single.await(
        'SELECT i.*, p.name AS plan_name, p.description AS plan_description, p.coverage_type, p.liability_limit, p.collision_limit, p.comprehensive_limit, p.deductible FROM st_vehicle_insurance i LEFT JOIN st_insurance_plans p ON p.id = i.plan_id WHERE i.vehicle_identifier = ? ORDER BY i.id DESC LIMIT 1',
        { vehicleIdentifier }
    )
end

function STInsurance.GetPolicyByNumber(policyNumber)
    if type(policyNumber) ~= 'string' or #policyNumber > 40 then
        return nil
    end

    return MySQL.single.await(
        'SELECT i.*, p.name AS plan_name, p.description AS plan_description, p.coverage_type, p.liability_limit, p.collision_limit, p.comprehensive_limit, p.deductible FROM st_vehicle_insurance i LEFT JOIN st_insurance_plans p ON p.id = i.plan_id WHERE i.policy_number = ? LIMIT 1',
        { policyNumber:upper() }
    )
end

function STInsurance.IsPolicyActive(policy)
    if not policy or policy.status ~= 'active' then
        return false
    end

    local expiresAt = tonumber(policy.expires_at)
    return expiresAt ~= nil and expiresAt >= os.time()
end

function STInsurance.PurchasePolicy(data)
    if type(data) ~= 'table' then
        return false, 'invalid_data'
    end

    if not STValidation.IsIdentifier(data.ownerIdentifier) then
        return false, 'invalid_owner_identifier'
    end

    if not STValidation.IsIdentifier(data.vehicleIdentifier) then
        return false, 'invalid_vehicle_identifier'
    end

    local plan = getPlan(data.planId)
    if not plan then
        return false, 'invalid_plan'
    end

    local existing = STInsurance.GetPolicy(data.vehicleIdentifier)
    if existing and STInsurance.IsPolicyActive(existing) then
        return false, 'active_policy_exists'
    end

    local policyNumber = generatePolicyNumber()
    if not policyNumber then
        return false, 'policy_number_generation_failed'
    end

    local now = os.time()
    local expiresAt = now + ((Config.Insurance.PolicyDurationDays or 30) * 86400)

    local insertId = MySQL.insert.await([[ 
        INSERT INTO st_vehicle_insurance
            (vehicle_identifier, owner_identifier, policy_number, plan_id, premium, effective_at, expires_at, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'active')
    ]], {
        data.vehicleIdentifier,
        data.ownerIdentifier,
        policyNumber,
        plan.id,
        plan.monthly_premium,
        now,
        expiresAt
    })

    if not insertId then
        return false, 'database_insert_failed'
    end

    return true, STInsurance.GetPolicy(data.vehicleIdentifier)
end

function STInsurance.RenewPolicy(vehicleIdentifier)
    local policy = STInsurance.GetPolicy(vehicleIdentifier)
    if not policy then
        return false, 'policy_not_found'
    end

    local now = os.time()
    local baseTime = math.max(now, tonumber(policy.expires_at) or now)
    local expiresAt = baseTime + ((Config.Insurance.PolicyDurationDays or 30) * 86400)

    local affected = MySQL.update.await([[ 
        UPDATE st_vehicle_insurance
        SET effective_at = CASE WHEN status <> 'active' OR expires_at < ? THEN ? ELSE effective_at END,
            expires_at = ?,
            status = 'active',
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { now, now, expiresAt, policy.id })

    if affected ~= 1 then
        return false, 'database_update_failed'
    end

    return true, STInsurance.GetPolicy(vehicleIdentifier)
end

function STInsurance.CancelPolicy(vehicleIdentifier, reason)
    local policy = STInsurance.GetPolicy(vehicleIdentifier)
    if not policy then
        return false, 'policy_not_found'
    end

    local affected = MySQL.update.await([[ 
        UPDATE st_vehicle_insurance
        SET status = 'cancelled', cancellation_reason = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { reason or 'Cancelled', policy.id })

    return affected == 1, affected == 1 and STInsurance.GetPolicy(vehicleIdentifier) or 'database_update_failed'
end

function STInsurance.IsVehicleInsured(vehicleIdentifier)
    return STInsurance.IsPolicyActive(STInsurance.GetPolicy(vehicleIdentifier))
end

function STInsurance.GetVehicleLegalStatus(vehicleIdentifier)
    local registration = STVehicles.GetRegistration(vehicleIdentifier)
    local policy = STInsurance.GetPolicy(vehicleIdentifier)

    local registrationActive = registration ~= nil
        and registration.status == 'active'
        and tonumber(registration.expires_at) >= os.time()

    local insuranceActive = STInsurance.IsPolicyActive(policy)

    return {
        registered = registrationActive,
        insured = insuranceActive,
        registration = registration,
        insurance = policy,
        legal = registrationActive and insuranceActive
    }
end

exports('GetInsurancePlans', STInsurance.GetPlans)
exports('GetInsurancePlan', STInsurance.GetPlan)
exports('GetVehicleInsurance', STInsurance.GetPolicy)
exports('GetInsurancePolicy', STInsurance.GetPolicyByNumber)
exports('PurchaseVehicleInsurance', STInsurance.PurchasePolicy)
exports('RenewVehicleInsurance', STInsurance.RenewPolicy)
exports('CancelVehicleInsurance', STInsurance.CancelPolicy)
exports('IsVehicleInsured', STInsurance.IsVehicleInsured)
exports('GetVehicleLegalStatus', STInsurance.GetVehicleLegalStatus)
