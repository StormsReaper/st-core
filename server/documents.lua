STDocuments = {}
local function addToOxInventory(source,itemName,metadata)
 if GetResourceState('ox_inventory')~='started' then return false,'ox_inventory_not_started' end
 local ok,result=pcall(function() return exports.ox_inventory:AddItem(source,itemName,1,metadata) end)
 if not ok or result==false or result==nil then return false,'item_add_failed' end return true,result
end
local function registrationMetadata(r) return {description=('Registration %s | %s | Plate %s'):format(r.registration_number or 'N/A',r.vehicle_display_name or r.vehicle_model or 'Vehicle',r.plate or 'N/A'),document_type='vehicle_registration',registration_id=r.id,registration_number=r.registration_number,vehicle_identifier=r.vehicle_identifier,plate=r.plate,plate_type=r.plate_type,owner_identifier=r.owner_identifier,owner_name=r.owner_name,vehicle_model=r.vehicle_model,vehicle_display_name=r.vehicle_display_name,purchase_price=r.purchase_price,dealership=r.dealership,registered_at=r.registered_at,expires_at=r.expires_at,status=r.status} end
local function insuranceMetadata(p) return {description=('Policy %s | %s | Plate %s'):format(p.policy_number or 'N/A',p.plan_name or 'Insurance',p.plate or 'N/A'),document_type='insurance_card',policy_id=p.id,policy_number=p.policy_number,insurance_company=Config.Insurance.CompanyName,insured_name=p.owner_name or p.insured_name,owner_identifier=p.owner_identifier,vehicle_identifier=p.vehicle_identifier,plate=p.plate,vehicle_model=p.vehicle_model,vehicle_display_name=p.vehicle_display_name,coverage=p.plan_name,coverage_type=p.coverage_type,liability_limit=p.liability_limit,collision_limit=p.collision_limit,comprehensive_limit=p.comprehensive_limit,deductible=p.deductible,premium=p.premium,effective_at=p.effective_at,expires_at=p.expires_at,status=p.status} end
function STDocuments.CreateRegistrationDocument(source,r) if not r then return false,'registration_not_found' end return addToOxInventory(source,Config.Documents.RegistrationItem,registrationMetadata(r)) end
function STDocuments.CreateInsuranceCard(source,p) if not p then return false,'policy_not_found' end return addToOxInventory(source,Config.Documents.InsuranceCardItem,insuranceMetadata(p)) end
function STDocuments.CreateTitleDocument(source,t)
 if not t then return false,'title_not_found' end
 return addToOxInventory(source,Config.Documents.TitleItem,{description=('Title %s | %s'):format(t.title_number or 'N/A',t.title_status or 'clear'),document_type='vehicle_title',title_id=t.id,title_number=t.title_number,vehicle_identifier=t.vehicle_identifier,owner_identifier=t.owner_identifier,owner_name=t.owner_name,title_status=t.title_status,issue_date=t.issue_date})
end
function STDocuments.CreateDriverLicense(source,l)
 if not l then return false,'license_not_found' end
 return addToOxInventory(source,Config.Documents.DriverLicenseItem,{description=('Driver License %s | Class %s'):format(l.license_number or 'N/A',l.class or 'C'),document_type='driver_license',license_id=l.id,license_number=l.license_number,owner_identifier=l.owner_identifier,owner_name=l.owner_name,class=l.class,endorsements=l.endorsements,restrictions=l.restrictions,points=l.points,status=l.status,issued_at=l.issued_at,expires_at=l.expires_at})
end
exports('CreateRegistrationDocument',STDocuments.CreateRegistrationDocument)
exports('CreateInsuranceCard',STDocuments.CreateInsuranceCard)
exports('CreateTitleDocument',STDocuments.CreateTitleDocument)
exports('CreateDriverLicense',STDocuments.CreateDriverLicense)
