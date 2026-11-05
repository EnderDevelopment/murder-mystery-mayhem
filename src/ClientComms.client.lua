--[[
    ClientComms.client.lua
    Client-side inter-process communication.
    Handles tool equipping, ammunition display, and shooting.
    Place in StarterPlayerScripts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("MM2Remotes")
local ToolRemotes = Remotes:WaitForChild("ToolRemotes")
local AttackEvent = ToolRemotes:WaitForChild("AttackEvent")
local HitEvent = ToolRemotes:WaitForChild("HitEvent")

local ammoLabel = nil
local maxAmmo = 3
local currentAmmo = maxAmmo

-- Create ammo display
local function createAmmoDisplay()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AmmoGUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local label = Instance.new("TextLabel")
    label.Name = "Ammo"
    label.Size = UDim2.new(0.12, 0, 0.06, 0)
    label.Position = UDim2.new(0.86, 0, 0.85, 0)
    label.BackgroundColor3 = Color3.new(0, 0, 0)
    label.BackgroundTransparency = 0.5
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = ""
    label.Visible = false
    label.Parent = gui

    return label
end

ammoLabel = createAmmoDisplay()

-- Update ammo display based on equipped tool
local function updateToolUI()
    local char = player.Character
    if not char then return end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool.Name == "Gun" then
        ammoLabel.Visible = true
        ammoLabel.Text = "Ammo: " .. currentAmmo
    else
        ammoLabel.Visible = false
    end
end

-- Register tool auto-equip once (backpack persists across character resets)
local backpack = player:WaitForChild("Backpack", 10)

backpack.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        -- Auto-equip new tools given by the server
        local char = player.Character
        if char then
            task.wait(0.1)
            if child and child.Parent == backpack and char.Parent then
                child.Parent = char
                AttackEvent:FireServer(child.Name)
                updateToolUI()
            end
        end
    end
end)

-- Handle character reset for tool UI
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    updateToolUI()
end)

-- Handle shooting: click with a gun tool
local function onMouseClick()
    local char = player.Character
    if not char then return end

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "Gun" then return end

    if currentAmmo <= 0 then
        -- Out of ammo: brief flash
        ammoLabel.TextColor3 = Color3.new(1, 0, 0)
        task.delay(0.5, function()
            if ammoLabel then
                ammoLabel.TextColor3 = Color3.new(1, 1, 1)
            end
        end)
        return
    end

    -- Raycast from camera
    local camera = workspace.CurrentCamera
    local origin = camera.CFrame.Position
    local direction = camera.CFrame.LookVector * 300

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char, playerGui, workspace:FindFirstChild("Coins") }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)
    if result and result.Instance then
        -- Check if we hit another player
        local humanoid = result.Instance.Parent:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            humanoid = result.Instance.Parent.Parent and result.Instance.Parent.Parent:FindFirstChildOfClass("Humanoid")
        end

        if humanoid then
            local targetPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
            if targetPlayer then
                HitEvent:FireServer(targetPlayer, "Gun")
                currentAmmo = math.max(0, currentAmmo - 1)
                ammoLabel.Text = "Ammo: " .. currentAmmo
            end
        end
    end
end

-- Handle melee with knife
local function onMouseDown()
    local char = player.Character
    if not char then return end

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "Knife" then return end

    -- For melee, find nearest target in range
    local humanoidRoot = char:FindFirstChild("HumanoidRootPart")
    if not humanoidRoot then return end

    local nearest = nil
    local nearestDist = 24

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherChar = otherPlayer.Character
            if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                local dist = (humanoidRoot.Position - otherChar.HumanoidRootPart.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = otherPlayer
                end
            end
        end
    end

    if nearest then
        HitEvent:FireServer(nearest, "Knife")
    end
end

-- Bind mouse buttons
local function setupMouse()
    local mouse = player:GetMouse()
    mouse.Button1Down:Connect(function()
        onMouseClick()
        onMouseDown()
    end)
end

task.spawn(setupMouse)

-- Track ammo UI
local lastSheriffRole = false
task.spawn(function()
    while true do
        task.wait(1)
        local role = player:GetAttribute("Role")
        local isSheriff = (role == "Sheriff")
        if isSheriff and not lastSheriffRole then
            -- New round as sheriff: reset ammo display
            currentAmmo = maxAmmo
            updateToolUI()
        end
        lastSheriffRole = isSheriff
    end
end)

print("[Murder Mystery 2 ClientComms] Loaded!")
