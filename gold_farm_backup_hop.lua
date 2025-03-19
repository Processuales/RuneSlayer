-- Config
local ENABLED = true
local WAIT_TIME = 250
local MIN_PLAYERS = 12

local SCRIPT_URL = "https://raw.githubusercontent.com/Processuales/RuneSlayer/refs/heads/main/gold_farm_backup_hop.lua"
local RECENT_FOLDER = "ServerHopData"
local TELEPORT_LOCK_FILE = RECENT_FOLDER .. "/TeleportLock.txt"

local BACKUP_PLACE_ID = 99995671928896
local BACKUP_SERVERS = {
    "df73ac43-2b1f-4677-825d-fd41e5a9889f",
    "3c3864fa-b114-400c-95a4-9cf20d1148a0",
    "30cf40e9-034e-492c-bffd-0deb1adcebbf",
    "bcf67808-9d70-48a9-a145-acf2fa906fb7",
    "dea60ce0-ecb8-4753-8764-4676d6c48819",
    "f671f9f3-c2ff-4b3c-9a63-15978d572944",
    "9585cada-b667-4be7-b5d6-4bb8a6e7faa7",
}

-- Ensure folder exists
if not isfolder(RECENT_FOLDER) then makefolder(RECENT_FOLDER) end
writefile(TELEPORT_LOCK_FILE, "false")

local function getTeleportLock()
    return isfile(TELEPORT_LOCK_FILE) and readfile(TELEPORT_LOCK_FILE) == "true"
end

local function setTeleportLock(status)
    writefile(TELEPORT_LOCK_FILE, status and "true" or "false")
end

game.Players.PlayerRemoving:Connect(function(plr)
    if plr == game.Players.LocalPlayer then
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end
end)

local function backupTeleport()
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = game.Players.LocalPlayer

    for _, jobId in ipairs(BACKUP_SERVERS) do
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(BACKUP_PLACE_ID, jobId, LocalPlayer)
        end)
        if ok then return end
        warn("[DEBUG] Backup teleport failed for "..jobId..": "..tostring(err))
    end
    warn("[DEBUG] All backup servers failed")
end

local function serverhop()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = game:GetService("Players").LocalPlayer

    local failureCount = 0
    local ServersUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local nextCursor

    repeat
        local ok, data = pcall(function()
            local url = ServersUrl .. (nextCursor and "&cursor=" .. nextCursor or "")
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not ok or not data or not data.data then
            failureCount = failureCount + 1
            warn("[DEBUG] Failed to retrieve servers. Retrying in 10 seconds...")
            if failureCount > 10 then return backupTeleport() end
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
                failureCount = 0
                table.sort(candidates, function(a,b) return a.playing < b.playing end)
                local chosen = candidates[1]
                print("[DEBUG] Hopping to server: "..chosen.id.." ("..chosen.playing.." players)")

                if queue_on_teleport then
                    pcall(function() queue_on_teleport(game:HttpGet(SCRIPT_URL)) end)
                end

                local startTime = tick()
                while getTeleportLock() do
                    if tick() - startTime > 10 then
                        warn("[DEBUG] Teleport lock stale, resetting")
                        setTeleportLock(false)
                        break
                    end
                    wait(1)
                end
                setTeleportLock(true)

                local success, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, LocalPlayer)
                end)
                if not success then
                    warn("[DEBUG] Teleport failed: "..tostring(err)..". Retrying...")
                    setTeleportLock(false)
                    wait(5)
                    setTeleportLock(true)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, LocalPlayer)
                end
                return
            end

            failureCount = failureCount + 1
            warn("[DEBUG] No eligible server found. Retrying in 10 seconds...")
            if failureCount > 10 then return backupTeleport() end
            wait(10)
        end
    until false
end

if ENABLED then
    print("[DEBUG] Backup script enabled. Waiting "..WAIT_TIME.." seconds before server hop.")
    wait(WAIT_TIME)
    serverhop()
end
