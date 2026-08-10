CreateThread(function()
    if Config.PrintStartupMessage then
        print(('[%s] Server initialized (v%s).'):format(Config.ResourceName, Config.Version))
    end
end)

CreateThread(function()
    while true do
        Wait(60 * 60 * 1000)

        local now = os.time()

        MySQL.update.await([[ 
            UPDATE st_vehicle_registrations
            SET status = 'expired', updated_at = CURRENT_TIMESTAMP
            WHERE status = 'active' AND expires_at < ?
        ]], { now })

        MySQL.update.await([[ 
            UPDATE st_vehicle_insurance
            SET status = 'expired', updated_at = CURRENT_TIMESTAMP
            WHERE status = 'active' AND expires_at < ?
        ]], { now })
    end
end)

RegisterCommand('stcore_server', function(source)
    if source == 0 then
        print(('[%s] Server resource is running.'):format(Config.ResourceName))
        return
    end

    print(('[%s] Player %s checked the server resource.'):format(Config.ResourceName, source))
end, false)
