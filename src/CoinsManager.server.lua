--[[
    CoinsManager.server.lua
    Manages coin spawning, collection and economy.
    Place in ServerScriptService.
]]

local CoinsManager = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
    CoinValue = 1,
    SpawnInterval = 3,
    MaxCoins = 20,
    CoinLifetime = 60,
}

local coinFolder = nil
local spawnConnection = nil

local Remotes = ReplicatedStorage:WaitForChild("MM2Remotes")
local CoinPickupRemote = Instance.new("RemoteEvent")
CoinPickupRemote.Name = "CoinPickup"
CoinPickupRemote.Parent = Remotes

local function getCoinFolder()
    if not coinFolder or not coinFolder.Parent then
        coinFolder = Workspace:FindFirstChild("Coins")
        if not coinFolder then
            coinFolder = Instance.new("Folder")
            coinFolder.Name = "Coins"
            coinFolder.Parent = Workspace
        end
    end
    return coinFolder
end

local function getCoinSpawns()
    local spawns = Workspace:FindFirstChild("CoinSpawns")
    if not spawns then
        warn("[CoinsManager] No CoinSpawns folder found in Workspace")
        return {}
    end
    local list = {}
    for _, child in ipairs(spawns:GetChildren()) do
        if child:IsA("Part") or child:IsA("BasePart") then
            table.insert(list, child)
        end
    end
    return list
end

local function createCoinModel(spawnPosition)
    local coin = Instance.new("Part")
    coin.Name = "Coin"
    coin.Size = Vector3.new(0.5, 0.15, 0.5)
    coin.Material = Enum.Material.Neon
    coin.BrickColor = BrickColor.new("Bright yellow")
    coin.Anchored = true
    coin.CanCollide = false
    coin.CFrame = CFrame.new(spawnPosition)
    coin.Parent = getCoinFolder()

    -- Add a touch bomb to detect pickup
    local touchBomb = Instance.new("ProximityPrompt")
    touchBomb.Name = "Pickup"
    touchBomb.Parent = coin
    touchBomb.MaxActivationDistance = 8
    touchBomb.RequiresLineOfSight = false
    touchBomb.Enabled = true
    touchBomb.PromptText = "Collect Coin"
    touchBomb.ActionText = "Go collect the coin!"

    touchBomb.Triggered:Connect(function(player)
        CoinsManager.CollectCoin(player, coin)
    end)

    -- Fade in with tween
    local tweenService = game:GetService("TweenService")
    coin.Transparency = 1
    local tween = tweenService:Create(coin, TweenInfo.new(0.3), { Transparency = 0 })
    tween:Play()

    -- Spin animation on the coin
    task.spawn(function()
        local potential = 0
        while coin and coin.Parent do
            task.wait(0.05)
            coin.CFrame = coin.CFrame * CFrame.Angles(0, math.rad(3), 0)
            potential += 0.05
            if potential >= CONFIG.CoinLifetime then
                coin:Destroy()
                break
            end
        end
    end)

    -- Remove after lifetime
    task.delay(CONFIG.CoinLifetime, function()
        if coin and coin.Parent then
            coin:Destroy()
        end
    end)

    return coin
end

local function spawnCoinRandom()
    local spawns = getCoinSpawns()
    if #spawns == 0 then return end

    local currentCoins = 0
    for _, child in ipairs(getCoinFolder():GetChildren()) do
        if child.Name == "Coin" then
            currentCoins += 1
        end
    end

    if currentCoins >= CONFIG.MaxCoins then return end

    local spawn = spawns[math.random(1, #spawns)]
    local pos = spawn.Position + Vector3.new(0, 1.5, 0)
    createCoinModel(pos)
end

function CoinsManager.StartSpawning()
    CoinsManager.StopSpawning()
    spawnConnection = task.spawn(function()
        while task.wait(CONFIG.SpawnInterval) do
            spawnCoinRandom()
        end
    end)
end

function CoinsManager.StopSpawning()
    if spawnConnection then
        task.cancel(spawnConnection)
        spawnConnection = nil
    end
end

function CoinsManager.CollectCoin(player, coin)
    if not player or not coin then return end
    if not coin.Parent then return end -- already collected

    local stats = player:FindFirstChild("leaderstats")
    if stats and stats.Coins then
        stats.Coins.Value += CONFIG.CoinValue
    end

    coin:Destroy()
    CoinPickupRemote:FireClient(player, CONFIG.CoinValue)
end

-- for clients that touch coins via Touched
CoinPickupRemote.OnServerEvent:Connect(function(player, coinInstance)
    if coinInstance and coinInstance.Name == "Coin" then
        CoinsManager.CollectCoin(player, coinInstance)
    end
end)

function CoinsManager.SetupPlayer(player)
    local stats = player:WaitForChild("leaderstats", 5)
    if stats then
        if not stats:FindFirstChild("Coins") then
            local coins = Instance.new("IntValue")
            coins.Name = "Coins"
            coins.Value = 0
            coins.Parent = stats
        end
    end
end

function CoinsManager.ResetRound()
    for _, child in ipairs(getCoinFolder():GetChildren()) do
        if child.Name == "Coin" then
            child:Destroy()
        end
    end
end

return CoinsManager
