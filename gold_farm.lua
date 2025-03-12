loadstring(game:HttpGet("https://raw.githubusercontent.com/0xCiel/RuneSlayerScript/refs/heads/main/main.lua"))()

getgenv().DontSell = {
    "Gold Ore", 
}
getgenv().OnlyMine = {
    "Gold",
    "Mithril",
    "Platinum",

}
getgenv().Slot = "Slot_2"
getgenv().Autofarm = true

print("Script loaded successfully!")
task.wait(5)
queue_on_teleport(
    'loadstring(game:HttpGet("https://raw.githubusercontent.com/Processuales/RuneSlayer/refs/heads/main/gold_farm.lua",false))()'
)

local scc, err = pcall(function()
    local Teleport, Mine = loadstring(game:HttpGet("https://raw.githubusercontent.com/Processuales/RuneSlayer/refs/heads/main/gold_farm.lua"))()

    -- Remove all lava parts
    for i, v in game:GetDescendants() do
        if v.Name == "lava" then
            v:Destroy()
        end
    end

    -- Function for server hopping
    local function serverhop()
        local TeleportService = game:GetService("TeleportService")
        local HttpService = game:GetService("HttpService")

        local ServersUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local Server, Next = nil, nil

        local function ListServers(cursor)
            local Raw = game:HttpGet(ServersUrl .. ((cursor and "&cursor=" .. cursor) or ""))
            return HttpService:JSONDecode(Raw)
        end

        repeat
            local Servers = ListServers(Next)
            Server = Servers.data[math.random(1, (#Servers.data / 3))]
            Next = Servers.nextPageCursor

            if Server and Server.playing < Server.maxPlayers and Server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, Server.id, game.Players.LocalPlayer)
                return
            end
        until not Next
        warn("No suitable server found, retrying...")
        serverhop()
    end

    -- Detect if the player is dead and instantly server hop
    local function detectDeath()
        local character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            humanoid.Died:Connect(function()
                warn("DETECTED PLAYER DEATH: INSTANT SERVER HOPPING")
                serverhop()
            end)
        end
    end

    -- Call the function to start death detection
    detectDeath()

    -- Ensure player is in the game
    if game.Players.LocalPlayer and not workspace:WaitForChild("Alive"):FindFirstChild(game.Players.LocalPlayer.Name) then
        game.Players.LocalPlayer:WaitForChild("ClientNetwork")
        game.Players.LocalPlayer:WaitForChild("ClientNetwork"):WaitForChild("MenuOptions")
        task.wait(2)
        game:GetService("Players").LocalPlayer.ClientNetwork.MenuOptions:FireServer({config = "start_screen"})
        task.wait(6)
        game:GetService("Players").LocalPlayer.ClientNetwork.MenuOptions:FireServer({slot = getgenv().Slot, config = "slots"})
        repeat
            task.wait()
        until game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
    end

    -- Sell Items
    game:GetService("Players").LocalPlayer.Character:WaitForChild("CharacterHandler")
    game:GetService("Players").LocalPlayer.Character.CharacterHandler.Input.Events.SellEvent:FireServer(true)

    -- Detect when a new item is added to backpack and sell it
    game.Players.LocalPlayer.Backpack.ChildAdded:Connect(function(child)
        if child and not table.find(getgenv().DontSell, child.Name) then
            game:GetService("Players").LocalPlayer.Character.CharacterHandler.Input.Events.SellEvent:FireServer(child)
        end
    end)

    -- Auto mine
    for i, v in workspace.Harvestable:GetChildren() do
        if not getgenv().Autofarm then
            break
        end
        if v:FindFirstChild("Icosphere") and table.find(getgenv().OnlyMine, v.Name) then
            Teleport(v)
            task.wait(0.2)
            Mine(v)
            task.wait(0.3)
        end
    end

    task.wait(2)
    print("CYCLE ENDED, WAITING 2 SECONDS BEFORE SERVERHOPPING")
    serverhop()
end)

-- Proper error handling
if not scc then
    error("SCRIPT ERRORED: " .. tostring(err))
end
