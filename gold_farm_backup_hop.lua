--[[ 
    New Server Hop Script

    This script waits for 250 seconds.
    After that, it forces a server hop to a server with at least 12 players.
    Set ENABLED to true to activate the script.
--]]

-- Config
local ENABLED = false
local WAIT_TIME = 250
local MIN_PLAYERS = 12

-- Replace the URL with the location of your script code
local SCRIPT_URL = "https://raw.githubusercontent.com/Processuales/RuneSlayer/refs/heads/main/gold_farm_backup_hop.lua"

-- Server hop function without checking recent servers
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
                        -- Fetch the script from an online source
                        queue_on_teleport(game:HttpGet(SCRIPT_URL))
                    end)
                    if not successQueue then
                        warn("[DEBUG] Failed to queue script on teleport: " .. tostring(err))
                    else
                        print("[DEBUG] Script queued on teleport.")
                    end
                end

                local tpSuccess, tpError = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, chosenServer.id, LocalPlayer)
                end)
                if not tpSuccess then
                    warn("[DEBUG] Teleport failed: " .. tostring(tpError) .. ". Retrying in 10 seconds...")
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
    print("[DEBUG] Backups script enabled. Waiting " .. WAIT_TIME .. " seconds before forcing a server hop.")
    wait(WAIT_TIME)
    serverhop()
end
