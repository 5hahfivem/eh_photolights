local functions = {}
local config = require('config')

local drops = {}
local dropIdCounter = 0

local function SetColour(src, id, data)
    if not id or not data or not data.colour then
        return
    end

    local drop = drops[id]
    if not drop then
        return
    end

    drop.light = data
    TriggerClientEvent('eh:photolights:setcolour', -1, id, data)
end
functions.SetColour = SetColour

local function DeleteDrop(id)
    if drops[id] then
        drops[id] = nil
        TriggerClientEvent('eh:photolights:deleteDrop', -1, id)
    end
end

local function DropProp(src, itemId, coords, itemName)
    if not itemId or not coords or not itemName then
        return
    end

    local itemConfig = nil
    for _, item in ipairs(config.ITEMS) do
        if item.name == itemName then
            itemConfig = item
            break
        end
    end
    if not itemConfig then
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, itemName, 1, nil, true)
    if not removed then
        return
    end

    dropIdCounter = dropIdCounter + 1
    local id = dropIdCounter

    local data = {
        id = id,
        itemId = itemId,
        item = itemName,
        position = coords,
        owner = src,
        model = itemConfig.model
    }

    drops[id] = data
    TriggerClientEvent('eh:photolights:drop', -1, data)

    SetTimeout(config.DROP_LIFETIME * 60 * 1000, function()
        DeleteDrop(id)
    end)
end
functions.DropProp = DropProp

local function PickupDrop(src, id)
    local drop = drops[id]
    if not drop then
        return
    end

    local added = exports.ox_inventory:AddItem(src, drop.item, 1)
    if not added then
        return
    end

    drops[id] = nil
    TriggerClientEvent('eh:photolights:deleteDrop', -1, id)
end
functions.PickupDrop = PickupDrop

local function UsePhotolights(source, item)
    for _, configItem in ipairs(config.ITEMS) do
        if item.name == configItem.name then
            TriggerClientEvent('eh:photolights:useItem', source, item.slot, configItem.model, configItem.name)
            return
        end
    end
end

for _, item in ipairs(config.ITEMS) do
    exports.qbx_core:CreateUseableItem(item.name, UsePhotolights)
end

RegisterNetEvent('eh:photolights:setcolour', function(id, data)
    SetColour(source, id, data)
end)

RegisterNetEvent('eh:photolights:dropProp', function(itemId, coords, itemName)
    DropProp(source, itemId, coords, itemName)
end)

RegisterNetEvent('eh:photolights:pickupDrop', function(id)
    PickupDrop(source, id)
end)

CreateThread(function()
    while true do
        Wait(10 * 1000)
        for id, drop in pairs(drops) do
            local player = GetPlayerPed(drop.owner)
            if not player or not DoesEntityExist(player) then
                DeleteDrop(id)
            else
                local playerCoords = GetEntityCoords(player)
                local dx, dy, dz = playerCoords.x - drop.position.x, playerCoords.y - drop.position.y, playerCoords.z - drop.position.z
                local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

                if distance > config.MAX_DISTANCE then
                    DeleteDrop(id)
                end
            end
        end
    end
end)

return functions