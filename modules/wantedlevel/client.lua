-- GTA dispatch service ids (EnableDispatchService). Each toggle in
-- Config.wantedLevel switches a group of them off; false leaves that group at stock behaviour.
local groups = {
    disablePolice = { 1, 2, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }, -- police cars/heli/swat/riders/roadblocks/boats/army/gangs/bikers
    disableFire = { 3 },                                             -- fire department
    disableAmbulance = { 5 },                                        -- ambulance department
}

local cfg = Config.wantedLevel or {}

CreateThread(function()
    SetMaxWantedLevel(0)

    for option, services in pairs(groups) do
        if cfg[option] ~= false then
            for i = 1, #services do
                EnableDispatchService(services[i], false)
            end
        end
    end
end)
