STDocuments = {}

local function addToOxInventory(source, itemName, metadata)
    if GetResourceState('ox_inventory') ~= 'started' then
        return false, 'ox_inventory_not_started'
    end

    local ok, result = pcall(function()
        return exports.ox_inventory:AddItem(source, itemName, 1, metadata)
    end)

    if not ok then return false, 'inventory_error' end
    if result == false or result == nil then return false, 'item_add_failed' end
    return true, result
end

function STDocuments.CreateInsuranceCard(source, policy)
    if not policy then return false, 'policy_not_found' end

    local metadata = {
        description = ('Policy %s | %s | Plate %s'):format(
            policy.policy_number or 'N/A',
            policy.plan_name or 'Insurance',
            policy.plate or 'N/A'
        ),
        policy_number = policy.policy_number,
        insurance_company = policy.insurance_company or Config.Insurance.CompanyName,
        insured_name = policy.insured_name,
        vehicle_identifier = policy.vehicle_identifier,
        plate = policy.plate,
        coverage = policy.plan_name,
        coverage_type = policy.coverage_type,
        liability_limit = policy.liability_limit,
        collision_limit = policy.collision_limit,
        comprehensive_limit = policy.comprehensive_limit,
        deductible = policy.deductible,
        premium = policy.premium,
        effective_at = policy.effective_at,
        expires_at = policy.expires_at
    }

    return addToOxInventory(source, Config.Documents.InsuranceCardItem, metadata)
end

exports('CreateInsuranceCard', STDocuments.CreateInsuranceCard)
