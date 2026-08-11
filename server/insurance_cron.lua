CreateThread(function()
    while true do
        Wait(300000)
        local expired = MySQL.query.await([[SELECT vehicle_identifier FROM st_vehicle_insurance WHERE status='active' AND expires_at < ?]], { os.time() }) or {}
        if #expired > 0 then
            MySQL.update.await("UPDATE st_vehicle_insurance SET status='expired', updated_at=CURRENT_TIMESTAMP WHERE status='active' AND expires_at < ?", { os.time() })
            for _, policy in ipairs(expired) do
                STVehicles.SyncVehicleRecord(policy.vehicle_identifier)
            end
        end
    end
end)
