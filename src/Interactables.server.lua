--[[
    Interactables.server.lua
    Manages map interactables (doors, chests, shops, coin drops).
    Place in ServerScriptService.
]]

local Interactables = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("MM2Remotes")
local InteractRemote = Instance.new("RemoteEvent")
InteractRemote.Name = "InteractRemote"
InteractRemote.Parent = Remotes

local doorStates = {}
local chestStates = {}

local function getInteractables()
    return Workspace:FindFirstChild("Interactables") or Instance.new("Folder")
end

-- Handle ClickDetector interactions
function Interactables.SetupMap()
    doorStates = {}
    chestStates = {}

    local interactablesFolder = Workspace:FindFirstChild("Interactables")
    if not interactablesFolder then return end

    for _, obj in ipairs(interactablesFolder:GetChildren()) do
        if obj:IsA("Model") then
            if obj.Name:match("^Door") then
                doorStates[obj.Name] = { open = false, obj = obj }
            elseif obj.Name:match("^Chest") then
                chestStates[obj.Name] = { open = false, obj = obj }
            end

            local clickDetector = obj:FindFirstChild("ClickDetector")
            if not clickDetector then
                clickDetector = Instance.new("ClickDetector")
                clickDetector.Parent = obj
            end

            clickDetector.MaxActivationDistance = 12
            clickDetector.MouseClick:Connect(function(player)
                Interactables.OnClick(player, obj)
            end)
        end
    end
end

function Interactables.OnClick(player, obj)
    local name = obj.Name

    if name:match("^Door") then
        -- Toggle door
        local state = doorStates[name]
        if not state then return end
        state.open = not state.open

        -- Animate door
        for _, part in ipairs(obj:GetChildren()) do
            if part:IsA("Part") then
                if state.open then
                    -- Slide door open
                    local pivot = part:GetPivot()
                    local offset = part.CFrame.RightVector * 6
                    local tween = game:GetService("TweenService"):Create(
                        part,
                        TweenInfo.new(0.5),
                        { CFrame = pivot * CFrame.new(offset) }
                    )
                    tween:Play()
                else
                    local tween = game:GetService("TweenService"):Create(
                        part,
                        TweenInfo.new(0.5),
                        { CFrame = part.Parent:GetPivot().Position + Vector3.new(0, 0, 0) }
                    )
                    tween:Play()
                end
            end
        end

        InteractRemote:FireClient(player, "Door", name, state.open)

    elseif name:match("^Chest") then
        local state = chestStates[name]
        if not state then return end
        if state.open then return end

        state.open = true
        -- Find the part that's the chest lid
        local lid = obj:FindFirstChild("Lid") or obj:FindFirstChild("Top")
        if lid and lid:IsA("Part") then
            local tween = game:GetService("TweenService"):Create(
                lid,
                TweenInfo.new(0.3),
                { Orientation = Vector3.new(-70, 0, 0) }
            )
            tween:Play()
        end

        -- Give coins as a reward
        local stats = player:FindFirstChild("leaderstats")
        if stats and stats.Coins then
            stats.Coins.Value += 3
        end

        InteractRemote:FireClient(player, "Chest", name, true)
    end
end

-- Interact remote handler (client click fallback)
InteractRemote.OnServerEvent:Connect(function(player, interactType, objectName)
    local interactablesFolder = Workspace:FindFirstChild("Interactables")
    if not interactablesFolder then return end

    local obj = interactablesFolder:FindFirstChild(objectName)
    if obj then
        Interactables.OnClick(player, obj)
    end
end)

function Interactables.ResetMap()
    -- Close all doors and chests
    for name, state in pairs(doorStates) do
        state.open = false
        if state.obj then
            for _, part in ipairs(state.obj:GetChildren()) do
                if part:IsA("Part") then
                    local resetPos = part:GetPivot().Position
                    local tween = game:GetService("TweenService"):Create(
                        part,
                        TweenInfo.new(0.2),
                        { CFrame = CFrame.new(resetPos) }
                    )
                    tween:Play()
                end
            end
        end
    end

    for name, state in pairs(chestStates) do
        state.open = false
        if state.obj then
            local lid = state.obj:FindFirstChild("Lid") or state.obj:FindFirstChild("Top")
            if lid and lid:IsA("Part") then
                local tween = game:GetService("TweenService"):Create(
                    lid,
                    TweenInfo.new(0.2),
                    { Orientation = Vector3.new(0, 0, 0) }
                )
                tween:Play()
            end
        end
    end
end

return Interactables
