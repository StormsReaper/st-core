STPayments = {}

local function getQBCore()
    if GetResourceState('qb-core') ~= 'started' then return nil end
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    return ok and core or nil
end

local function getESX()
    if GetResourceState('es_extended') ~= 'started' then return nil end
    local ok, esx = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    return ok and esx or nil
end

function STPayments.GetPlayer(source)
    local qb = getQBCore()
    if qb then
        return qb.Functions.GetPlayer(source), 'qbcore'
    end

    local esx = getESX()
    if esx then
        return esx.GetPlayerFromId(source), 'esx'
    end

    return nil, nil
end

function STPayments.GetIdentifier(source)
    local player = STPayments.GetPlayer(source)
    if not player then return nil end

    if player.PlayerData then
        return player.PlayerData.citizenid
    end

    return player.identifier
end

function STPayments.Remove(source, amount, account, reason)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'invalid_amount' end

    account = account or 'bank'
    local player, framework = STPayments.GetPlayer(source)
    if not player then return false, 'framework_player_not_found' end

    if framework == 'qbcore' then
        local balance = player.Functions.GetMoney(account)
        if balance < amount then return false, 'insufficient_funds' end
        local removed = player.Functions.RemoveMoney(account, amount, reason or Config.Payment.DefaultReason)
        return removed == true, removed == true and nil or 'payment_failed'
    end

    local accountObject = player.getAccount(account)
    if not accountObject or accountObject.money < amount then
        return false, 'insufficient_funds'
    end

    player.removeAccountMoney(account, amount, reason or Config.Payment.DefaultReason)
    return true
end

function STPayments.Add(source, amount, account, reason)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'invalid_amount' end

    account = account or 'bank'
    local player, framework = STPayments.GetPlayer(source)
    if not player then return false, 'framework_player_not_found' end

    if framework == 'qbcore' then
        return player.Functions.AddMoney(account, amount, reason or Config.Payment.DefaultReason) == true
    end

    player.addAccountMoney(account, amount, reason or Config.Payment.DefaultReason)
    return true
end

function STPayments.Charge(source, amount, reason)
    local accounts = Config.Payment.AccountPriority or { 'bank', 'cash' }
    for _, account in ipairs(accounts) do
        local ok, err = STPayments.Remove(source, amount, account, reason)
        if ok then return true, account end
        if err ~= 'insufficient_funds' then return false, err end
    end
    return false, 'insufficient_funds'
end

exports('ChargePlayer', STPayments.Charge)
exports('GetPlayerIdentifier', STPayments.GetIdentifier)
