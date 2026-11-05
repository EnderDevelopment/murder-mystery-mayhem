--[[
    PlayerGui.client.lua
    Main client UI for Murder Mystery 2.
    Place in StarterPlayerScripts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("MM2Remotes")
local SetRoundState = Remotes:WaitForChild("SetRoundState")
local UpdateTimer = Remotes:WaitForChild("UpdateTimer")
local KillBroadcast = Remotes:WaitForChild("KillBroadcast")
local LeaderboardEvent = Remotes:WaitForChild("LeaderboardEvent")
local ShopRemote = Remotes:WaitForChild("ShopRemote")
local RequestShop = Remotes:WaitForChild("RequestShop")
local RoundResult = Remotes:WaitForChild("RoundResult")

-- Utility to create a ScreenGui
local function createGui(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui
    return gui
end

-- ====== ROLE / STATE DISPLAY ======
local function setupStateGUI()
    local gui = createGui("StateGUI")

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0.4, 0, 0.1, 0)
    frame.Position = UDim2.new(0.5, 0, 0.05, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "StateLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "Waiting for players..."
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(0.3, 0, 0.15, 0)
    timerLabel.Position = UDim2.new(1, 0, 0, 0)
    timerLabel.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    timerLabel.TextColor3 = Color3.new(1, 1, 1)
    timerLabel.TextScaled = true
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.Parent = frame

    return { frame = frame, label = label, timer = timerLabel }
end

local stateUI = setupStateGUI()

-- Round result banner
local resultGui = createGui("ResultGUI")
local resultLabel = Instance.new("TextLabel")
resultLabel.Name = "ResultLabel"
resultLabel.Size = UDim2.new(0.4, 0, 0.1, 0)
resultLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
resultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
resultLabel.BackgroundColor3 = Color3.new(0, 0, 0)
resultLabel.BackgroundTransparency = 0.4
resultLabel.TextColor3 = Color3.new(1, 1, 1)
resultLabel.TextScaled = true
resultLabel.Font = Enum.Font.GothamBold
resultLabel.Text = ""
resultLabel.Visible = false
resultLabel.Parent = resultGui

local resultCorner = Instance.new("UICorner")
resultCorner.CornerRadius = UDim.new(0.1, 0)
resultCorner.Parent = resultLabel

-- ====== ROLE INDICATOR ======
local function setupRoleGUI()
    local gui = createGui("RoleGUI")

    local label = Instance.new("TextLabel")
    label.Name = "RoleLabel"
    label.Size = UDim2.new(0.5, 0, 0.08, 0)
    label.Position = UDim2.new(0.25, 0, 0.9, 0)
    label.BackgroundColor3 = Color3.new(0, 0, 0)
    label.BackgroundTransparency = 0.5
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = ""
    label.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = label

    return label
end

local roleLabel = setupRoleGUI()

-- ====== KILL FEED ======
local function setupKillFeed()
    local gui = createGui("KillFeed")

    local layout = Instance.new("UIListLayout")
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 4)
    layout.Parent = gui

    return gui
end

local killFeed = setupKillFeed()

local function addKillFeedEntry(killer, target, role)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.3, 0, 0.05, 0)
    label.Position = UDim2.new(0.7, 0, 0.1, 0)
    label.BackgroundColor3 = Color3.new(0, 0, 0)
    label.BackgroundTransparency = 0.6
    label.TextColor3 = Color3.new(1, 0.2, 0.2)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Text = string.format("%s killed %s", killer.Name, target.Name)
    label.Parent = killFeed

    task.delay(5, function()
        if label.Parent then
            local tween = TweenService:Create(label, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 })
            tween:Play()
            tween.Completed:Connect(function()
                label:Destroy()
            end)
        end
    end)
end

KillBroadcast.OnClientEvent:Connect(function(killer, target, role)
    addKillFeedEntry(killer, target, role)
end)

-- ====== LEADERBOARD ======
local function setupLeaderboard()
    local gui = createGui("LeaderboardGUI")
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = gui

    return gui
end

local leaderboardGui = setupLeaderboard()

LeaderboardEvent.OnClientEvent:Connect(function(sortedPlayers)
    -- Clear existing
    for _, child in ipairs(leaderboardGui:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    for i, data in ipairs(sortedPlayers) do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.18, 0, 0.04, 0)
        label.Position = UDim2.new(0.015, 0, 0.02 + (i - 1) * 0.045, 0)
        label.BackgroundColor3 = Color3.new(0, 0, 0)
        label.BackgroundTransparency = 0.4
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.Font = Enum.Font.Gotham
        label.Text = string.format("#%d %s — %d kills", i, data.Name, data.Kills)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = leaderboardGui
    end
end)

-- ====== EVENT HANDLERS ======
SetRoundState.OnClientEvent:Connect(function(state, time)
    stateUI.frame.Visible = true
    if state == "InGame" then
        stateUI.label.Text = "Round in progress"
        stateUI.label.TextColor3 = Color3.new(1, 0.3, 0.3)
        stateUI.timer.Visible = true
    elseif state == "Intermission" then
        stateUI.label.Text = "Intermission"
        stateUI.label.TextColor3 = Color3.new(0.3, 1, 0.3)
        stateUI.timer.Visible = true
    elseif state == "Waiting" then
        stateUI.label.Text = "Waiting for players..."
        stateUI.label.TextColor3 = Color3.new(1, 1, 1)
        stateUI.timer.Visible = false
    end
end)

UpdateTimer.OnClientEvent:Connect(function(timer)
    local minutes = math.floor(timer / 60)
    local seconds = timer % 60
    stateUI.timer.Text = string.format("%02d:%02d", minutes, seconds)
end)

-- Show round result with fade-out
RoundResult.OnClientEvent:Connect(function(winner)
    resultLabel.Visible = true
    if winner == "Murderer" then
        resultLabel.Text = "The MURDERER wins!"
        resultLabel.TextColor3 = Color3.new(1, 0, 0)
    elseif winner == "Innocents" then
        resultLabel.Text = "The INNOCENTS win!"
        resultLabel.TextColor3 = Color3.new(0, 1, 0)
    else
        resultLabel.Text = "Round Over"
        resultLabel.TextColor3 = Color3.new(1, 1, 1)
    end

    task.delay(3, function()
        local fade = TweenService:Create(resultLabel, TweenInfo.new(0.5), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
        })
        fade:Play()
        fade.Completed:Connect(function()
            resultLabel.Visible = false
            resultLabel.BackgroundTransparency = 0.4
            resultLabel.TextTransparency = 0
        end)
    end)
end)

-- ====== SHOP UI ======
local function setupShopUI()
    local gui = createGui("ShopGUI")
    gui.Enabled = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.5, 0, 0.6, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.15, 0)
    title.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
    title.Text = "Weapon Shop"
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0.8, 0, 0.1, 0)
    closeBtn.Position = UDim2.new(0.1, 0, 0.85, 0)
    closeBtn.BackgroundColor3 = Color3.new(0.5, 0.1, 0.1)
    closeBtn.Text = "Close"
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = frame

    closeBtn.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    local shopItems = {}

    -- Request shop items from server
    local success, items = pcall(function()
        return RequestShop:InvokeServer()
    end)

    if success and items then
        for i, item in ipairs(items) do
            local itemLabel = Instance.new("TextLabel")
            itemLabel.Size = UDim2.new(0.8, 0, 0.08, 0)
            itemLabel.BackgroundColor3 = Color3.new(0.25, 0.25, 0.35)
            itemLabel.Text = string.format("%s — %d coins", item.Name, item.Price)
            itemLabel.TextScaled = true
            itemLabel.Font = Enum.Font.Gotham
            itemLabel.TextColor3 = Color3.new(1, 1, 1)
            itemLabel.Parent = frame

            local buyBtn = Instance.new("TextButton")
            buyBtn.Size = UDim2.new(0.8, 0, 0.08, 0)
            buyBtn.BackgroundColor3 = Color3.new(0.1, 0.5, 0.1)
            buyBtn.Text = "Buy " .. item.Name
            buyBtn.TextScaled = true
            buyBtn.Font = Enum.Font.GothamBold
            buyBtn.Parent = frame

            buyBtn.MouseButton1Click:Connect(function()
                ShopRemote:FireServer(item.Name)
            end)
        end
    end

    return gui
end

local shopGui = setupShopUI()

-- Open/close shop with P key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        shopGui.Enabled = not shopGui.Enabled
    end
end)

-- Open shop via server remote (shop NPC interaction)
local OpenShopUI = Remotes:FindFirstChild("OpenShopUI")
if OpenShopUI then
    OpenShopUI.OnClientEvent:Connect(function()
        shopGui.Enabled = true
    end)
end

-- Handle shop purchase feedback
ShopRemote.OnClientEvent:Connect(function(messageType, message)
    if messageType == "Success" then
        -- Show success feedback briefly
        shopGui.Enabled = false
    elseif messageType == "Error" then
        -- Show error message
        print("[Shop Error]: " .. message)
    end
end)

-- ====== ROLE ANNOUNCEMENT PERIODICALLY ======
-- The role is sent via attributes which replicate to clients
local lastDisplayedRole = ""
task.spawn(function()
    while true do
        task.wait(0.5)
        local role = player:GetAttribute("Role")
        if role ~= lastDisplayedRole then
            lastDisplayedRole = role or ""
            if role == "Murderer" then
                roleLabel.Text = "You are the MURDERER!"
                roleLabel.TextColor3 = Color3.new(1, 0, 0)
            elseif role == "Sheriff" then
                roleLabel.Text = "You are the SHERIFF!"
                roleLabel.TextColor3 = Color3.new(0, 0.5, 1)
            elseif role == "Innocent" then
                roleLabel.Text = "You are an INNOCENT"
                roleLabel.TextColor3 = Color3.new(0, 1, 0)
            else
                roleLabel.Text = ""
                roleLabel.TextColor3 = Color3.new(1, 1, 1)
            end
        end
    end
end)

-- ====== WEAPON CONTROLS ======
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local humanoid = char:WaitForChild("Humanoid")
end)

-- Simple mouse-click tool handling will be done by Tool scripts
-- which the server creates. Client just equips.
print("[Murder Mystery 2] Client loaded successfully!")
