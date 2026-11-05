--[[
    ShopHandler.server.lua
    Handles weapon shop purchases and shop interactions.
    Place in ServerScriptService.
]]

local ShopHandler = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("MM2Remotes")
local ShopRemote = Instance.new("RemoteEvent")
ShopRemote.Name = "ShopRemote"
ShopRemote.Parent = Remotes

-- Shop items: name -> { price, weaponName, desc }
local SHOP_ITEMS = {
    Knife = {
        Price = 25,
        WeaponName = "Knife",
        Description = "A knife for self-defense (doesn't kill innocents).",
    },
    Gun = {
        Price = 50,
        WeaponName = "Gun",
        Description = "A gun. Be careful - firing at an innocent gets you banned from the shop.",
    },
    Medkit = {
        Price = 15,
        WeaponName = "Medkit",
        Description = "Restores your health to full.",
    },
}

function ShopHandler.SetupPlayer(player)
    -- No special setup needed, but we keep the API consistent
end

-- Purchase handler
ShopRemote.OnServerEvent:Connect(function(player, itemName)
    local item = SHOP_ITEMS[itemName]
    if not item then return end

    local stats = player:FindFirstChild("leaderstats")
    if not stats or not stats.Coins then
        return
    end

    local price = item.Price
    local coins = stats.Coins.Value
    if coins < price then
        ShopRemote:FireClient(player, "Error", "Not enough coins!")
        return
    end

    -- Deduct payment
    stats.Coins.Value = coins - price

    -- Give the item
    if itemName == "Medkit" then
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.Health = char.Humanoid.MaxHealth
        end
        ShopRemote:FireClient(player, "Success", "Health restored!")
    else
        -- Give weapon (need weapon manager)
        local weaponManager = require(script.Parent:WaitForChild("WeaponManager"))
        weaponManager.GiveWeapon(player, item.WeaponName)
        ShopRemote:FireClient(player, "Success", "Purchased " .. itemName .. "!")
    end
end)

-- Client requests the shop item list
local RequestShopRemote = Instance.new("RemoteFunction")
RequestShopRemote.Name = "RequestShop"
RequestShopRemote.Parent = Remotes

RequestShopRemote.OnServerInvoke = function(player)
    local items = {}
    for name, data in pairs(SHOP_ITEMS) do
        table.insert(items, {
            Name = name,
            Price = data.Price,
            Description = data.Description,
        })
    end
    return items
end

-- Set up shop NPCs/interactables in the map
function ShopHandler.SetupShops(mapFolder)
    local shops = Workspace:FindFirstChild("Shops")
    if not shops then return end

    for _, shopModel in ipairs(shops:GetChildren()) do
        local prompt = shopModel:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            prompt = Instance.new("ProximityPrompt")
            prompt.Name = "OpenShop"
            prompt.Parent = shopModel
            prompt.MaxActivationDistance = 15
            prompt.PromptText = "Open Shop"
            prompt.ActionText = "Browse the metal shop"
        end

        prompt.Triggered:Connect(function(player)
            -- Give them the shop UI via remote
            local uiEvent = Remotes:FindFirstChild("OpenShopUI")
            if not uiEvent then
                uiEvent = Instance.new("RemoteEvent")
                uiEvent.Name = "OpenShopUI"
                uiEvent.Parent = Remotes
            end
            uiEvent:FireClient(player)
        end)
    end
end

function ShopHandler.ResetRound()
    -- nothing to reset for shop
end

return ShopHandler
