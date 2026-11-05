--[[
    GameManager.server.lua
    Core server script for Murder Mystery 2.
    Place in ServerScriptService.
]]

local CONFIG = {
    RoundTime = 240,              -- seconds per round
    IntermissionTime = 15,        -- seconds between rounds
    MinPlayers = 2,               -- minimum players to start
    CoinCooldown = 5,             -- seconds between coin spawns
    MaxCoinsOnMap = 20,           -- max coins active at once
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = Instance.new("Folder")
Remotes.Name = "MM2Remotes"
Remotes.Parent = ReplicatedStorage

local SetRoundState = Instance.new("RemoteEvent")
SetRoundState.Name = "SetRoundState"
SetRoundState.Parent = Remotes

local UpdateTimer = Instance.new("RemoteEvent")
UpdateTimer.Name = "UpdateTimer"
UpdateTimer.Parent = Remotes

local RoundResult = Instance.new("RemoteEvent")
RoundResult.Name = "RoundResult"
RoundResult.Parent = Remotes

local GameState = {
    CurrentState = "Intermission",
    Timer = 0,
    Round = 0,
}

local roundActive = false

local roleManager = require(script.Parent:WaitForChild("RoleAssigner"))
local weaponManager = require(script.Parent:WaitForChild("WeaponManager"))
local interactableManager = require(script.Parent:WaitForChild("Interactables"))
local coinManager = require(script.Parent:WaitForChild("CoinsManager"))
local shopManager = require(script.Parent:WaitForChild("ShopHandler"))
local mapManager = require(script.Parent:WaitForChild("MapManager"))
local currentRoundId = 0

local function broadcastState(state, time)
    GameState.CurrentState = state
    GameState.Timer = time
    SetRoundState:FireAllClients(state, time)
end

local function broadcastTimer(timer)
    UpdateTimer:FireAllClients(timer)
end

local function onRoundEnd(winner)
    if not roundActive then return end
    roundActive = false
    coinManager:StopSpawning()
    weaponManager:ResetRound()
    roleManager:ResetRoles()

    RoundResult:FireAllClients(winner or "Tie")
    broadcastState("Intermission", CONFIG.IntermissionTime)
    GameState.Round += 1

    -- Give a small coin bonus to all players for participation
    for _, player in ipairs(Players:GetPlayers()) do
        local stats = player:FindFirstChild("leaderstats")
        if stats and stats.Coins then
            stats.Coins.Value += 2
        end
    end

    task.wait(CONFIG.IntermissionTime)
    startRound()
end

local function checkRoundEnd()
    local alivePlayers = 0
    local murdererAlive = false
    local sheriffAlive = false

    for _, player in ipairs(Players:GetPlayers()) do
        local role = player:GetAttribute("Role") or "Innocent"
        local alive = player:GetAttribute("Alive")
        if alive ~= false then
            alivePlayers += 1
            if role == "Murderer" then murdererAlive = true end
            if role == "Sheriff" then sheriffAlive = true end
        end
    end

    if not murdererAlive then
        -- Innocents win
        for _, player in ipairs(Players:GetPlayers()) do
            local stats = player:FindFirstChild("leaderstats")
            if stats then
                local role = player:GetAttribute("Role")
                if role ~= "Murderer" and role ~= nil then
                    stats.Wins.Value += 1
                end
            end
        end
        onRoundEnd("Innocents")
        return
    end

    if alivePlayers <= 1 and murdererAlive then
        -- Murderer wins
        for _, player in ipairs(Players:GetPlayers()) do
            local stats = player:FindFirstChild("leaderstats")
            if stats then
                local role = player:GetAttribute("Role")
                if role == "Murderer" then
                    stats.Wins.Value += 1
                end
            end
        end
        onRoundEnd("Murderer")
    end
end

local function startRound()
    local players = Players:GetPlayers()
    if #players < CONFIG.MinPlayers then
        broadcastState("Waiting", 999)
        -- wait for players
        while #Players:GetPlayers() < CONFIG.MinPlayers do
            task.wait(1)
        end
        startRound()
        return
    end

    currentRoundId += 1
    local myRoundId = currentRoundId
    roundActive = true
    mapManager:RandomizeMap()
    mapManager:ResetMap()
    roleManager:AssignRoles()

    for _, player in ipairs(players) do
        if player:GetAttribute("Role") == "Murderer" then
            weaponManager:GiveWeapon(player, "Knife")
        elseif player:GetAttribute("Role") == "Sheriff" then
            weaponManager:GiveWeapon(player, "Gun")
        end
    end

    coinManager:StartSpawning()
    interactableManager:SetupMap()
    shopManager:SetupShops()
    broadcastState("InGame", CONFIG.RoundTime)
    broadcastTimer(CONFIG.RoundTime)

    -- Round timer loop
    local elapsed = 0
    while elapsed < CONFIG.RoundTime and roundActive and myRoundId == currentRoundId do
        task.wait(1)
        if myRoundId ~= currentRoundId then
            return -- a new round started
        end
        elapsed += 1
        broadcastTimer(CONFIG.RoundTime - elapsed)
        checkRoundEnd()
        if myRoundId ~= currentRoundId then
            return -- a new round started via onRoundEnd
        end
    end

    if myRoundId ~= currentRoundId then return end
    if not roundActive then return end

    -- Time ran out: murderer wins if alive
    local murdererAlive = false
    for _, player in ipairs(players) do
        if player:GetAttribute("Role") == "Murderer" and player:GetAttribute("Alive") ~= false then
            murdererAlive = true
            break
        end
    end

    if murdererAlive then
        for _, player in ipairs(players) do
            local stats = player:FindFirstChild("leaderstats")
            if stats and player:GetAttribute("Role") == "Murderer" then
                stats.Wins.Value += 1
            end
        end
    end
    onRoundEnd(murdererAlive and "Murderer" or "Innocents")
end

Players.PlayerAdded:Connect(function(player)
    roleManager:SetupPlayer(player)
    weaponManager:SetupPlayer(player)
    coinManager:SetupPlayer(player)
    shopManager:SetupPlayer(player)

    -- Handle character respawn to enforce death state
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        local alive = player:GetAttribute("Alive")
        if alive == false then
            -- Player is dead, make them a spectator
            local humanoid = char:WaitForChild("Humanoid")
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            humanoid.WalkSpeed = 16
            -- Hide weapons
            weaponManager.RemoveAllWeapons(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    -- handle disconnects during round
    if roundActive then
        -- Count remaining
        local aliveCount = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr:GetAttribute("Alive") ~= false then
                aliveCount += 1
            end
        end
        if aliveCount <= 1 then
            checkRoundEnd()
        end
    end
end)

-- Start the game loop
task.spawn(function()
    broadcastState("Waiting", 999)
    while true do
        -- Only start rounds when waiting for players and enough joined
        if GameState.CurrentState == "Waiting" and #Players:GetPlayers() >= CONFIG.MinPlayers then
            task.wait(3)
            if GameState.CurrentState == "Waiting" and #Players:GetPlayers() >= CONFIG.MinPlayers then
                startRound()
            end
        end
        task.wait(1)
    end
end)
