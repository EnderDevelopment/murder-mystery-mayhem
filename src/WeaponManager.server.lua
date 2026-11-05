--[[
    WeaponManager.server.lua
    Manages weapon giving, killing and hit detection.
    Place in ServerScriptService.
]]

local WeaponManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("MM2Remotes")

local ToolRemotes = Instance.new("Folder")
ToolRemotes.Name = "ToolRemotes"
ToolRemotes.Parent = Remotes

local HitEvent = Instance.new("RemoteEvent")
HitEvent.Name = "HitEvent"
HitEvent.Parent = ToolRemotes

local DropEvent = Instance.new("RemoteEvent")
DropEvent.Name = "DropEvent"
DropEvent.Parent = ToolRemotes

local PickupEvent = Instance.new("RemoteEvent")
PickupEvent.Name = "PickupEvent"
PickupEvent.Parent = ToolRemotes

local AttackEvent = Instance.new("RemoteEvent")
AttackEvent.Name = "AttackEvent"
AttackEvent.Parent = ToolRemotes

local KillBroadcast = Instance.new("RemoteEvent")
KillBroadcast.Name = "KillBroadcast"
KillBroadcast.Parent = Remotes

local weaponConfig = {
    Knife = {
        Damage = 100,
        Range = 24,
        Cooldown = 0.5,
    },
    Gun = {
        Damage = 100,
        Range = 300,
        Cooldown = 0.8,
        Ammo = 3,
    },
}

local playerCooldowns = {}
local playerAmmo = {}

-- Create tool instances for the player
local function createKnifeTool()
    local tool = Instance.new("Tool")
    tool.Name = "Knife"
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.Enabled = false  -- Prevent default activation, our ClientComms handles kills

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.2, 0.15, 1)
    handle.Material = Enum.Material.SmoothPlastic
    handle.BrickColor = BrickColor.new("Dark stone grey")
    handle.CanCollide = false
    handle.Parent = tool

    -- Blade
    local blade = Instance.new("Part")
    blade.Name = "Blade"
    blade.Size = Vector3.new(0.08, 0.08, 0.6)
    blade.Material = Enum.Material.Metal
    blade.BrickColor = BrickColor.new("Silver")
    blade.CanCollide = false
    blade.Position = Vector3.new(0, 0, 0.6)
    blade.Parent = tool

    -- Weld the blade to the handle so it moves together
    local weld = Instance.new("Weld")
    weld.Part0 = handle
    weld.Part1 = blade
    weld.Parent = handle

    return tool
end

local function createGunTool()
    local tool = Instance.new("Tool")
    tool.Name = "Gun"
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.Enabled = false  -- Prevent default activation, our ClientComms handles kills

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.12, 0.12, 0.8)
    handle.Material = Enum.Material.SmoothPlastic
    handle.BrickColor = BrickColor.new("Dark stone grey")
    handle.CanCollide = false
    handle.Parent = tool

    local barrel = Instance.new("Part")
    barrel.Name = "Barrel"
    barrel.Size = Vector3.new(0.08, 0.08, 0.5)
    barrel.Material = Enum.Material.Metal
    barrel.BrickColor = BrickColor.new("Medium stone grey")
    barrel.CanCollide = false
    barrel.Position = Vector3.new(0, 0, 0.6)
    barrel.Parent = tool

    -- Weld the barrel to the handle
    local weld = Instance.new("Weld")
    weld.Part0 = handle
    weld.Part1 = barrel
    weld.Parent = handle

    return tool
end

function WeaponManager.SetupPlayer(player)
    playerCooldowns[player.UserId] = {}
end

function WeaponManager.GiveWeapon(player, weaponName)
    local existing = player.Backpack:FindFirstChild(weaponName) or player.Character and player.Character:FindFirstChild(weaponName)
    if existing then return end

    local tool
    if weaponName == "Knife" then
        tool = createKnifeTool()
    elseif weaponName == "Gun" then
        tool = createGunTool()
        playerAmmo[player.UserId] = weaponConfig.Gun.Ammo
    else
        return
    end

    tool.Parent = player.Backpack
end

function WeaponManager.RemoveAllWeapons(player)
    for _, item in ipairs(player.Backpack:GetChildren()) do
        if item:IsA("Tool") then
            item:Destroy()
        end
    end
    if player.Character then
        for _, item in ipairs(player.Character:GetChildren()) do
            if item:IsA("Tool") then
                item:Destroy()
            end
        end
    end
    playerAmmo[player.UserId] = nil
end

-- Check if target is valid and alive
local function canKill(attacker, target)
    if not attacker or not target then return false end
    if attacker == target then return false end

    local attackerAlive = attacker:GetAttribute("Alive")
    local targetAlive = target:GetAttribute("Alive")
    if attackerAlive == false or targetAlive == false then return false end

    local attackerRole = attacker:GetAttribute("Role")
    local targetRole = target:GetAttribute("Role")

    -- Murderer can kill everyone
    if attackerRole == "Murderer" then
        return true
    end

    -- Sheriff can only kill murderer
    if attackerRole == "Sheriff" then
        return targetRole == "Murderer"
    end

    -- Innocents can't kill
    return false
end

-- Process a kill
function WeaponManager.ProcessKill(attacker, target)
    if not canKill(attacker, target) then return end

    local attackerRole = attacker:GetAttribute("Role")
    local stats = attacker:FindFirstChild("leaderstats")
    if stats then
        stats.Kills.Value += 1
    end

    -- Award coins for the kill
    local coinStats = attacker:FindFirstChild("leaderstats")
    if coinStats and coinStats.Coins then
        coinStats.Coins.Value += 5
    end

    -- Handle target death
    target:SetAttribute("Alive", false)
    WeaponManager.RemoveAllWeapons(target)

    if target.Character and target.Character:FindFirstChild("Humanoid") then
        local humanoid = target.Character.Humanoid
        humanoid.Health = 0
    end

    -- Broadcast kill effect
    KillBroadcast:FireAllClients(attacker, target, attackerRole)
end

-- Handle hits from tools
HitEvent.OnServerEvent:Connect(function(player, targetPlayer, weaponName)
    local cooldown = playerCooldowns[player.UserId] and playerCooldowns[player.UserId][weaponName] or 0
    local now = os.clock()
    if now - cooldown < (weaponConfig[weaponName] and weaponConfig[weaponName].Cooldown or 0.5) then
        return -- still cooling down (anti-cheat)
    end
    playerCooldowns[player.UserId] = playerCooldowns[player.UserId] or {}
    playerCooldowns[player.UserId][weaponName] = now

    if weaponName == "Gun" then
        local ammo = playerAmmo[player.UserId]
        if not ammo or ammo <= 0 then
            return -- out of ammo
        end
        playerAmmo[player.UserId] = ammo - 1
    end

    -- Distance check (anti-exploit)
    local char = player.Character
    local targetChar = targetPlayer.Character
    if not char or not targetChar then return end

    local range = weaponConfig[weaponName] and weaponConfig[weaponName].Range or 0
    if (char.HumanoidRootPart.Position - targetChar.HumanoidRootPart.Position).Magnitude > range then
        return -- too far away (anti-cheat)
    end

    WeaponManager.ProcessKill(player, targetPlayer)
end)

-- Tool equip into character
AttackEvent.OnServerEvent:Connect(function(player, weaponName)
    local tool = player.Backpack:FindFirstChild(weaponName)
    if tool then
        tool.Parent = player.Character
    end
end)

function WeaponManager.ResetRound()
    for _, player in ipairs(Players:GetPlayers()) do
        WeaponManager.RemoveAllWeapons(player)
        playerAmmo[player.UserId] = nil
        playerCooldowns[player.UserId] = {}
    end
end

return WeaponManager
