CreateThread(function()
    if Config.PrintStartupMessage then
        print(('[%s] Server initialized (v%s).'):format(Config.ResourceName, Config.Version))
    end
end)

RegisterCommand('stcore_server', function(source)
    if source == 0 then
        print(('[%s] Server resource is running.'):format(Config.ResourceName))
        return
    end

    print(('[%s] Player %s checked the server resource.'):format(Config.ResourceName, source))
end, true)
