--[[
    RoleAssigner.server.lua
    Assigns roles (Murderer, Sheriff, Innocent) each round.
    Place in ServerScriptService.
    Creates leaderstats with Kills, Wins, Coins on each player.
]]

local RoleAssigner = {}

local Players = game:GetService("Players")

function RoleAssigner.SetupPlayer(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local kills = Instance.new("IntValue")
    kills.Name = "Kills"
    kills.Value = 0
    kills.Parent = leaderstats

    local wins = Instance.new("IntValue")
    wins.Name = "Wins"
    wins.Value = 0
    wins.Parent = leaderstats

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = 0
    coins.Parent = leaderstats
end

-- Assign one murderer, one sheriff, rest are innocent
function RoleAssigner.AssignRoles()
    local players = Players:GetPlayers()
    if #players < 2 then return end

    -- First pick one murderer
    local murdererIndex = math.random(1, #players)
    local murderer = players[murdererIndex]
    murderer:SetAttribute("Role", "Murderer")
    murderer:SetAttribute("Alive", true)
    murderer:SetAttribute("LastRole", "Murderer")

    -- Then pick a sheriff from remaining players
    local remaining = {}
    for i, player in ipairs(players) do
        if i ~= murdererIndex then
            table.insert(remaining, player)
        end
    end

    local sheriffIndex = math.random(1, #remaining)
    local sheriff = remaining[sheriffIndex]
    sheriff:SetAttribute("Role", "Sheriff")
    sheriff:SetAttribute("Alive", true)
    sheriff:SetAttribute("LastRole", "Sheriff")

    -- Everyone else is innocent
    for _, player in ipairs(remaining) do
        if player ~= sheriff then
            player:SetAttribute("Role", "Innocent")
            player:SetAttribute("Alive", true)
            player:SetAttribute("LastRole", "Innocent")
        end
    end
end

function RoleAssigner.ResetRoles()
    for _, player in ipairs(Players:GetPlayers()) do
        player:SetAttribute("Role", nil)
        player:SetAttribute("Alive", true)
    end
end

-- Award bonus kills to the sheriff for eliminating the murderer
function RoleAssigner.SheriffBonus()
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("Role") == "Sheriff" then
            local stats = player:FindFirstChild("leaderstats")
            if stats and stats.Kills then
                stats.Kills.Value += 1
            end
        end
    end
end

return RoleAssigner
