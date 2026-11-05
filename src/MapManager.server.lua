--[[
    MapManager.server.lua
    Manages map state, map switching and spawn points.
    Place in ServerScriptService.
]]

local MapManager = {}

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Maps list: model names in Workspace/Maps
local MAPS = {
    "Map1",
    "Map2",
    "Map3",
}

local currentMap = nil

local function getSpawnLocations()
    local spawns = Workspace:FindFirstChild("SpawnLocations")
    if not spawns then
        warn("[MapManager] No SpawnLocations folder")
        return {}
    end
    local locations = {}
    for _, part in ipairs(spawns:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(locations, part)
        end
    end
    return locations
end

-- Teleport all players to spawn points
function MapManager.TeleportPlayersToSpawns()
    local spawns = getSpawnLocations()
    if #spawns == 0 then return end

    local shuffled = {}
    for _, s in ipairs(spawns) do
        table.insert(shuffled, s)
    end

    -- shuffle
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local index = 1
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("Alive") ~= false then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local spawn = shuffled[index % #shuffled + 1]
                char:PivotTo(spawn:GetPivot())
                index += 1
            end
        end
    end
end

-- Reset player states with full health
function MapManager.ResetPlayerStates()
    for _, player in ipairs(Players:GetPlayers()) do
        player:SetAttribute("Alive", true)
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Health = humanoid.MaxHealth
                humanoid.PlatformStand = false
            end
            -- Remove any dropped tools
        end
    end
end

-- Switch active map by name
function MapManager.LoadMap(mapName)
    local mapsFolder = Workspace:FindFirstChild("Maps")
    if not mapsFolder then return end

    -- Hide all maps
    for _, map in ipairs(mapsFolder:GetChildren()) do
        if map:IsA("Model") then
            map:PivotTo(map:GetPivot() + Vector3.new(0, -10000, 0))
        end
    end

    -- Show the desired map
    local target = mapsFolder:FindFirstChild(mapName)
    if target then
        target:PivotTo(target:GetPivot() + Vector3.new(0, 10000, 0))
        currentMap = mapName
    end
end

-- Reset the current map: restore coins/doors etc.
function MapManager.ResetMap()
    MapManager.ResetPlayerStates()
    MapManager.TeleportPlayersToSpawns()

    -- Reset interactable managers
    local interactables = require(script.Parent:WaitForChild("Interactables"))
    interactables.ResetMap()

    local coinsManager = require(script.Parent:WaitForChild("CoinsManager"))
    coinsManager.ResetRound()

    -- Choose random map if not set
    if not currentMap then
        local mapsFolder = Workspace:FindFirstChild("Maps")
        if mapsFolder and #mapsFolder:GetChildren() > 0 then
            currentMap = mapsFolder:GetChildren()[math.random(1, #mapsFolder:GetChildren())].Name
        end
    end

    MapManager.LoadMap(currentMap or "Map1")
end

-- Called each round to randomize map
function MapManager.RandomizeMap()
    local mapsFolder = Workspace:FindFirstChild("Maps")
    if mapsFolder then
        local children = mapsFolder:GetChildren()
        if #children > 0 then
            currentMap = children[math.random(1, #children)].Name
        end
    end
end

function MapManager.GetCurrentMap()
    return currentMap
end

return MapManager
