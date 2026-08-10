CreateThread(function()
    if Config.PrintStartupMessage then
        print(('[%s] Client initialized (v%s).'):format(Config.ResourceName, Config.Version))
    end
end)

RegisterCommand('stcore', function()
    print(('[%s] Client resource is running.'):format(Config.ResourceName))
end, false)
