STDocuments = {}

local function addToOxInventory(source, itemName, metadata)
    if GetResourceState('ox_inventory') ~= 'started' then return false, 'ox_inventory_not_started' end
    local ok, result = pcall(function() return exports.ox_inventory:AddItem(source, itemName, 1, metadata) end)
    if not ok or result == false or result == nil then return false, 'item_add_failed' end
    return true, result
end

local function registrationMetadata(registration)
    return {
        description = ('Registration %s | %s | Plate %s'):format(registration.registration_number or 'N/A', registration.vehicle_display_name or registration.vehicle_model or 'Vehicle', registration.plate or 'N/A'),
        document_type = 'vehicle_registration', registration_id = registration.id,
        registration_number = registration.registration_number, vehicle_identifier = registration.vehicle_identifier,
        plate = registration.plate, plate_type = registration.plate_type, owner_identifier = registration.owner_identifier,
        owner_name = registration.owner_name, vehicle_model = registration.vehicle_model, vehicle_display_name = registration.vehicle_display_name,
        purchase_price = registration.purchase_price, dealership = registration.dealership, registered_at = registration.registered_at,
        expires_at = registration.expires_at, status = registration.status,
    }
end

local function insuranceMetadata(policy)
    return {
        description = ('Policy %s | %s | Plate %s'):format(policy.policy_number or 'N/A', policy.plan_name or 'Insurance', policy.plate or 'N/A'),
        document_type = 'insurance_card', policy_id = policy.id, policy_number = policy.policy_number,
        insurance_company = Config.Insurance.CompanyName, insured_name = policy.owner_name, owner_identifier = policy.owner_identifier,
        vehicle_identifier = policy.vehicle_identifier, plate = policy.plate, vehicle_model = policy.vehicle_model,
        vehicle_display_name = policy.vehicle_display_name, coverage = policy.plan_name, coverage_type = policy.coverage_type,
        liability_limit = policy.liability_limit, collision_limit = policy.collision_limit, comprehensive_limit = policy.comprehensive_limit,
        deductible = policy.deductible, premium = policy.premium, effective_at = policy.effective_at, expires_at = policy.expires_at,
        status = policy.status,
    }
end

function STDocuments.CreateRegistrationDocument(source, registration)
    if not registration then return false, 'registration_not_found' end
    return addToOxInventory(source, 'vehicle_registration', registrationMetadata(registration))
end

function STDocuments.CreateInsuranceCard(source, policy)
    if not policy then return false, 'policy_not_found' end
    return addToOxInventory(source, Config.Documents.InsuranceCardItem, insuranceMetadata(policy))
end

exports('CreateRegistrationDocument', STDocuments.CreateRegistrationDocument)
exports('CreateInsuranceCard', STDocuments.CreateInsuranceCard)
