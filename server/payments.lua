STPayments = {}

local function getQBCore()
    if GetResourceState('qb-core') ~= 'started' then return nil end
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    return ok and core or nil
end
local function getESX()
    if GetResourceState('es_extended') ~= 'started' then return nil end
    local ok, esx = pcall(function() return exports['es_extended']:getSharedObject() end)
    return ok and esx or nil
end
function STPayments.GetPlayer(source)
    local qb=getQBCore();if qb then return qb.Functions.GetPlayer(source),'qbcore' end
    local esx=getESX();if esx then return esx.GetPlayerFromId(source),'esx' end
    return nil,nil
end
function STPayments.GetIdentifier(source)local p=STPayments.GetPlayer(source);if not p then return nil end;if p.PlayerData then return p.PlayerData.citizenid end;return p.identifier end
function STPayments.GetName(source)local p,f=STPayments.GetPlayer(source);if not p then return nil end;if f=='qbcore' then local c=p.PlayerData and p.PlayerData.charinfo or {};local n=(tostring(c.firstname or '')..' '..tostring(c.lastname or '')):gsub('^%s+',''):gsub('%s+$','');return n~=''and n or p.PlayerData.name end;if p.getName then return p.getName()end;return p.name end
local function validAmount(a)a=tonumber(a);return a and a>0 and a<=1000000000 and a==math.floor(a*100)/100 end
function STPayments.Balance(source,account)
 account=account or 'bank';local p,f=STPayments.GetPlayer(source);if not p then return nil,'framework_player_not_found'end
 if f=='qbcore' then return tonumber(p.Functions.GetMoney(account))or 0 end
 local a=p.getAccount(account);return a and tonumber(a.money)or nil,'account_not_found'
end
function STPayments.Remove(source,amount,account,reason)
 if not validAmount(amount)then return false,'invalid_amount'end;account=account or'bank';local p,f=STPayments.GetPlayer(source);if not p then return false,'framework_player_not_found'end
 if f=='qbcore' then local b=STPayments.Balance(source,account);if b<amount then return false,'insufficient_funds'end;return p.Functions.RemoveMoney(account,amount,reason or Config.Payment.DefaultReason)==true and true or false,'payment_failed'end
 local a=p.getAccount(account);if not a or a.money<amount then return false,'insufficient_funds'end;p.removeAccountMoney(account,amount,reason or Config.Payment.DefaultReason);return true
end
function STPayments.Add(source,amount,account,reason)
 if not validAmount(amount)then return false,'invalid_amount'end;account=account or'bank';local p,f=STPayments.GetPlayer(source);if not p then return false,'framework_player_not_found'end
 if f=='qbcore' then return p.Functions.AddMoney(account,amount,reason or Config.Payment.DefaultReason)==true and true or false,'payment_failed'end
 local a=p.getAccount(account);if not a then return false,'account_not_found'end;p.addAccountMoney(account,amount,reason or Config.Payment.DefaultReason);return true
end
function STPayments.Charge(source,amount,reason)
 if not validAmount(amount)then return false,'invalid_amount'end
 local accounts=Config.Payment.AccountPriority or{'bank','cash'}
 for _,account in ipairs(accounts)do local ok,err=STPayments.Remove(source,amount,account,reason);if ok then return true,account end;if err~='insufficient_funds'then return false,err end end
 return false,'insufficient_funds'
end
function STPayments.Credit(source,amount,reason)return STPayments.Add(source,amount,'bank',reason)end
function STPayments.Transfer(source,target,amount,reason)
 if source==target then return false,'same_account'end;if not validAmount(amount)then return false,'invalid_amount'end
 local ok,err=STPayments.Remove(source,amount,'bank',reason or'Bank transfer');if not ok then return false,err end
 local added,addErr=STPayments.Add(target,amount,'bank',reason or'Bank transfer');if not added then STPayments.Add(source,amount,'bank','Transfer reversal');return false,addErr or'credit_failed'end
 return true
end
function STPayments.Require(source,amount,reason)local ok,account=STPayments.Charge(source,amount,reason);if not ok then return false,account end;return true,account end
exports('ChargePlayer',STPayments.Charge)
exports('GetPlayerIdentifier',STPayments.GetIdentifier)
exports('GetPlayerName',STPayments.GetName)
exports('GetPlayerBalance',STPayments.Balance)
exports('CreditPlayer',STPayments.Credit)
exports('TransferPlayer',STPayments.Transfer)
exports('RequirePayment',STPayments.Require)
