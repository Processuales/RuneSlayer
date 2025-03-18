--[[ 
    New Server Hop Script

    This script waits for 250 seconds.
    After that, it forces a server hop to a server with at least 12 players.
    Set ENABLED to true to activate the script.
--]]

-- Config
local ENABLED = true
local WAIT_TIME = 250
local MIN_PLAYERS = 12

local SCRIPT_URL = "https://raw.githubusercontent.com/Processuales/RuneSlayer/refs/heads/main/gold_farm_backup_hop.lua"
local RECENT_FOLDER = "ServerHopData"
local TELEPORT_LOCK_FILE = RECENT_FOLDER .. "/TeleportLock.txt"

-- Ensure the folder exists
if not isfolder(RECENT_FOLDER) then
    makefolder(RECENT_FOLDER)
end

-- At the start of this backup script, reset the teleport lock to false.
writefile(TELEPORT_LOCK_FILE, "false")

-- Teleport lock functions (backup only reads the lock; it does not set it to true)
local function getTeleportLock()
    if isfile(TELEPORT_LOCK_FILE) then
        local data = readfile(TELEPORT_LOCK_FILE)
        return data == "true"
    else
        return false
    end
end

local function setTeleportLock(status)
    writefile(TELEPORT_LOCK_FILE, status and "true" or "false")
end

-- In case of kick, teleport back to the same place.
game.Players.PlayerRemoving:Connect(function(plr)
    if plr == game.Players.LocalPlayer then
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end
end)

-- Server hop function with teleport lock and error handling.
local function serverhop()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local ServersUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local NextPageCursor = nil
    local chosenServer = nil

    local function ListServers(cursor)
        local url = ServersUrl .. (cursor and ("&cursor=" .. cursor) or "")
        local Raw = game:HttpGet(url)
        return HttpService:JSONDecode(Raw)
    end

    repeat
        local success, Servers = pcall(function() return ListServers(NextPageCursor) end)
        if not success or not Servers or not Servers.data then
            warn("[DEBUG] Failed to retrieve servers. Retrying in 10 seconds...")
            wait(10)
        else
            NextPageCursor = Servers.nextPageCursor

            local eligibleServers = {}
            for _, server in ipairs(Servers.data) do
                if server.id ~= game.JobId and server.playing >= MIN_PLAYERS then
                    table.insert(eligibleServers, server)
                end
            end

            if #eligibleServers > 0 then
                table.sort(eligibleServers, function(a, b)
                    return a.playing < b.playing
                end)
                chosenServer = eligibleServers[1]
                print("[DEBUG] Hopping to server: " .. chosenServer.id .. " (" .. chosenServer.playing .. " players)")
                
                -- Queue the script on teleport if possible
                if queue_on_teleport then
                    local successQueue, err = pcall(function()
                        queue_on_teleport(game:HttpGet(SCRIPT_URL))
                    end)
                    if not successQueue then
                        warn("[DEBUG] Failed to queue script on teleport: " .. tostring(err))
                    else
                        print("[DEBUG] Script queued on teleport.")
                    end
                end

                -- Wait for teleport lock to be free and then lock it
                while getTeleportLock() do
                    print("[DEBUG] Teleport lock active, waiting...")
                    wait(1)
                end
                setTeleportLock(true)

                local tpSuccess, tpError = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, chosenServer.id, LocalPlayer)
                end)
                if not tpSuccess then
                    warn("[DEBUG] Teleport failed: " .. tostring(tpError) .. ". Resetting teleport lock and retrying in 10 seconds...")
                    setTeleportLock(false)
                    wait(10)
                end
                return
            end

            if not NextPageCursor then
                warn("[DEBUG] No eligible server found. Retrying in 10 seconds...")
                wait(10)
            end
        end
    until chosenServer ~= nil

    warn("[DEBUG] No server available. Retrying in 10 seconds...")
    wait(10)
    serverhop()
end

if ENABLED then
    print("[DEBUG] Backup script enabled. Waiting " .. WAIT_TIME .. " seconds before forcing a server hop.")
    wait(WAIT_TIME)
    serverhop()
end
