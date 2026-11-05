--[[
    Leaderboard.server.lua
    Tracks and displays round results and leaderboard.
    Place in ServerScriptService.
]]

local Leaderboard = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("MM2Remotes")
local LeaderboardEvent = Instance.new("RemoteEvent")
LeaderboardEvent.Name = "LeaderboardEvent"
LeaderboardEvent.Parent = Remotes

-- Update the leaderboard every 5 seconds
task.spawn(function()
    while true do
        task.wait(5)
        Leaderboard.UpdateAll()
    end
end)

local function getTotalKills(player)
    local stats = player:FindFirstChild("leaderstats")
    if stats and stats.Kills then
        return stats.Kills.Value
    end
    return 0
end

function Leaderboard.UpdateAll()
    local sortedPlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(sortedPlayers, {
            Name = player.Name,
            Kills = getTotalKills(player),
        })
    end

    -- Sort descending by kills
    table.sort(sortedPlayers, function(a, b)
        return a.Kills > b.Kills
    end)

    LeaderboardEvent:FireAllClients(sortedPlayers)
end

function Leaderboard.BroadcastRoundResult(winnerRole)
    local resultEvent = Remotes:FindFirstChild("RoundResult")
    if not resultEvent then
        resultEvent = Instance.new("RemoteEvent")
        resultEvent.Name = "RoundResult"
        resultEvent.Parent = Remotes
    end
    resultEvent:FireAllClients(winnerRole)
end

Leaderboard.ResetRound = function()
    -- re-broadcast after each round reset
    Leaderboard.UpdateAll()
end

return Leaderboard
