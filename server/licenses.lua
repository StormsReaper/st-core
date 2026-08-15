STLicenses = {}
local function licenseNumber() for _=1,50 do local n=('DL-%08d'):format(math.random(0,99999999)); if not MySQL.single.await('SELECT id FROM st_driver_licenses WHERE license_number=? LIMIT 1',{n}) then return n end end end
function STLicenses.Get(identifier) return MySQL.single.await('SELECT * FROM st_driver_licenses WHERE owner_identifier=? LIMIT 1',{identifier}) end
function STLicenses.GetByNumber(number) return MySQL.single.await('SELECT * FROM st_driver_licenses WHERE license_number=? LIMIT 1',{number}) end
function STLicenses.Issue(identifier,name,class,duration)
    local existing=STLicenses.Get(identifier); if existing then return true,existing end
    local n=licenseNumber(); if not n then return false,'number_generation_failed' end
    local now=os.time(); local exp=now+((tonumber(duration) or 365)*86400)
    local id=MySQL.insert.await('INSERT INTO st_driver_licenses (license_number,owner_identifier,owner_name,class,issued_at,expires_at) VALUES (?,?,?,?,?,?)',{n,identifier,name or 'Unknown',class or 'C',now,exp})
    return id ~= nil, id and STLicenses.Get(identifier) or 'database_insert_failed'
end
function STLicenses.SetStatus(identifier,status) return MySQL.update.await('UPDATE st_driver_licenses SET status=?,updated_at=CURRENT_TIMESTAMP WHERE owner_identifier=?',{status,identifier})==1 end
function STLicenses.AddPoints(identifier,points,reason,actor)
    local l=STLicenses.Get(identifier); if not l then return false,'license_not_found' end
    points=tonumber(points) or 0; local new=math.max(0,(tonumber(l.points) or 0)+points)
    local status=l.status; if new>=Config.LicensePointsSuspend then status='suspended' end
    MySQL.update.await('UPDATE st_driver_licenses SET points=?,status=?,updated_at=CURRENT_TIMESTAMP WHERE owner_identifier=?',{new,status,identifier})
    MySQL.insert.await('INSERT INTO st_driver_license_events (license_number,actor_identifier,event_type,points_delta,reason) VALUES (?,?,?,?,?)',{l.license_number,actor,'points',points,reason})
    return true,STLicenses.Get(identifier)
end
function STLicenses.Renew(identifier,duration) local l=STLicenses.Get(identifier); if not l then return false,'license_not_found' end local exp=math.max(os.time(),tonumber(l.expires_at) or 0)+((tonumber(duration) or 365)*86400); MySQL.update.await("UPDATE st_driver_licenses SET expires_at=?,status='valid',updated_at=CURRENT_TIMESTAMP WHERE owner_identifier=?",{exp,identifier}); return true,STLicenses.Get(identifier) end
exports('GetDriverLicense',STLicenses.Get); exports('GetDriverLicenseByNumber',STLicenses.GetByNumber); exports('IssueDriverLicense',STLicenses.Issue); exports('SetDriverLicenseStatus',STLicenses.SetStatus); exports('AddDriverLicensePoints',STLicenses.AddPoints); exports('RenewDriverLicense',STLicenses.Renew)
