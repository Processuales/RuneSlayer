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

-- Ensure folder exists
if not isfolder(RECENT_FOLDER) then
    makefolder(RECENT_FOLDER)
end

-- Reset teleport lock at start
writefile(TELEPORT_LOCK_FILE, "false")

local function getTeleportLock()
    if isfile(TELEPORT_LOCK_FILE) then
        return readfile(TELEPORT_LOCK_FILE) == "true"
    end
    return false
end

local function setTeleportLock(status)
    writefile(TELEPORT_LOCK_FILE, status and "true" or "false")
end

-- Teleport back on kick
game.Players.PlayerRemoving:Connect(function(plr)
    if plr == game.Players.LocalPlayer then
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end
end)

local function serverhop()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = game:GetService("Players").LocalPlayer

    local ServersUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local nextCursor = nil

    repeat
        local ok, data = pcall(function()
            local url = ServersUrl .. (nextCursor and "&cursor=" .. nextCursor or "")
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if not ok or not data or not data.data then
            warn("[DEBUG] Failed to retrieve servers. Retrying in 10 seconds...")
            wait(10)
        else
            nextCursor = data.nextPageCursor
            local candidates = {}
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing >= MIN_PLAYERS then
                    table.insert(candidates, server)
                end
            end
            if #candidates > 0 then
                table.sort(candidates, function(a, b) return a.playing < b.playing end)
                local chosen = candidates[1]
                print("[DEBUG] Hopping to server: " .. chosen.id .. " (" .. chosen.playing .. " players)")

                if queue_on_teleport then
                    pcall(function()
                        queue_on_teleport(game:HttpGet(SCRIPT_URL))
                    end)
                end

                -- Wait for lock or timeout after 10 seconds
                local startTime = tick()
                while getTeleportLock() do
                    if tick() - startTime > 10 then
                        warn("[DEBUG] Teleport lock stale, forcing reset")
                        setTeleportLock(false)
                        break
                    end
                    print("[DEBUG] Teleport lock active, waiting...")
                    wait(1)
                end
                setTeleportLock(true)

                local success, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, LocalPlayer)
                end)
                if not success then
                    warn("[DEBUG] Teleport failed: " .. tostring(err))
                    setTeleportLock(false)
                    warn("[DEBUG] Retrying forced teleport in 5 seconds")
                    wait(5)
                    setTeleportLock(true)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, LocalPlayer)
                end
                return
            end
            if not nextCursor then
                warn("[DEBUG] No eligible server found. Retrying in 10 seconds...")
                wait(10)
            end
        end
    until false
end

if ENABLED then
    print("[DEBUG] Backup script enabled. Waiting " .. WAIT_TIME .. " seconds before server hop.")
    wait(WAIT_TIME)
    serverhop()
end
