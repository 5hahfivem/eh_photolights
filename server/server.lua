local config = require('shared.config')

-- Constants
local THROTTLE_COOLDOWNS = {
    SET_COLOUR = 500,
    DROP = 750,
    PICKUP = 500
}

local RGB_MIN = 0
local RGB_MAX = 255
local DISTANCE_CHECK_INTERVAL = 10000
local DISTANCE_TIMEOUT_DEFAULT = 15

-- Cache natives
local GetGameTimer = GetGameTimer
local GetPlayerPed = GetPlayerPed
local GetEntityCoords = GetEntityCoords
local DoesEntityExist = DoesEntityExist
local TriggerClientEvent = TriggerClientEvent
local SetTimeout = SetTimeout
local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min

-- State management
---@type table<number, any>
local drops = {}
local dropIdCounter = 0
---@type table<number, number>
local playerDropCounts = {}
---@type table<string, table<number, number>>
local lastActionAtMs = {
    setcolour = {},
    drop = {},
    pickup = {}
}

local function nowMs()
    return GetGameTimer()
end

local function clamp(n, min, max)
    return math_max(min, math_min(max, n))
end

local function isThrottled(bucket, src, cooldownMs)
    local last = lastActionAtMs[bucket][src]
    if last and (nowMs() - last) < cooldownMs then
        return true
    end
    lastActionAtMs[bucket][src] = nowMs()
    return false
end

---@param data table
---@return table|nil
local function validateAndClampColour(data)
    if type(data) ~= 'table' or type(data.colour) ~= 'table' then
        return nil
    end
    
    local c = data.colour
    local r = tonumber(c.red)
    local g = tonumber(c.green)
    local b = tonumber(c.blue)
    
    if not r or not g or not b then 
        return nil 
    end
    
    local clampedR = clamp(r, RGB_MIN, RGB_MAX)
    local clampedG = clamp(g, RGB_MIN, RGB_MAX)
    local clampedB = clamp(b, RGB_MIN, RGB_MAX)
    
    return {
        colour = {
            red = clampedR,
            green = clampedG,
            blue = clampedB
        },
        label = type(data.label) == 'string' and data.label or ("rgb(%d, %d, %d)"):format(clampedR, clampedG, clampedB)
    }
end

local function incrementCount(src)
    playerDropCounts[src] = (playerDropCounts[src] or 0) + 1
end

local function decrementCount(src)
    if not playerDropCounts[src] then 
        return 
    end
    
    playerDropCounts[src] = math_max(0, playerDropCounts[src] - 1)
    if playerDropCounts[src] == 0 then 
        playerDropCounts[src] = nil 
    end
end

local function getCount(src)
    return playerDropCounts[src] or 0
end

local function normalizeCoords(coords)
    if type(coords) == 'vector4' then
        return coords
    end
    
    if type(coords) == 'table' and coords.x and coords.y and coords.z and coords.w then
        return vector4(coords.x, coords.y, coords.z, coords.w)
    end
    
    error('Invalid coordinates format')
end

local function findItemConfig(itemName)
    for _, item in ipairs(config.ITEMS) do
        if item.name == itemName then
            return item
        end
    end
    return nil
end

local function calculateDistance(coords1, coords2)
    local dx = coords1.x - coords2.x
    local dy = coords1.y - coords2.y
    local dz = coords1.z - coords2.z
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

---@param src number
---@param id number
---@param data table
---@return boolean
local function setColour(src, id, data)
    if isThrottled('setcolour', src, THROTTLE_COOLDOWNS.SET_COLOUR) then 
        return false 
    end
    
    if type(id) ~= 'number' then 
        return false 
    end
    
    local validated = validateAndClampColour(data)
    if not validated then 
        return false 
    end

    local drop = drops[id]
    if not drop then
        return false
    end

    drop.light = validated
    TriggerClientEvent('hl:photolights:setcolour', -1, id, validated)
    return true
end

local function deleteDrop(id, opts)
    local drop = drops[id]
    if not drop then 
        return 
    end
    
    drops[id] = nil
    decrementCount(drop.owner)
    TriggerClientEvent('hl:photolights:deleteDrop', -1, id)
    
    if opts and opts.giveback and config.GIVEBACK_ON_DESPAWN then
        GiveItem(drop.owner, drop.item, 1)
    end
end

---@param src number
---@param itemId string
---@param coords vector4|table
---@param itemName string
---@return boolean, string?
local function dropProp(src, itemId, coords, itemName)
    if isThrottled('drop', src, THROTTLE_COOLDOWNS.DROP) then 
        return false 
    end
    
    if type(itemId) ~= 'string' or type(itemName) ~= 'string' then 
        return false 
    end
    
    local position = normalizeCoords(coords)
    local maxDrops = config.MAX_DROPS_PER_PLAYER or 5
    
    if getCount(src) >= maxDrops then
        return false, 'max_drops'
    end

    local itemConfig = findItemConfig(itemName)
    if not itemConfig then
        return false
    end

    local removed = RemoveItem(src, itemName, 1)
    if not removed then
        return false
    end

    dropIdCounter = dropIdCounter + 1
    local id = dropIdCounter

    local data = {
        id = id,
        itemId = itemId,
        item = itemName,
        position = position,
        owner = src,
        model = itemConfig.model,
        outOfRangeAtMs = nil
    }

    drops[id] = data
    incrementCount(src)
    TriggerClientEvent('hl:photolights:drop', -1, data)

    -- Set lifetime timeout
    local lifetimeMs = (config.DROP_LIFETIME or 15) * 60 * 1000
    SetTimeout(lifetimeMs, function()
        deleteDrop(id)
    end)

    return true
end

local function pickupDrop(src, id)
    if isThrottled('pickup', src, THROTTLE_COOLDOWNS.PICKUP) then 
        return false 
    end
    
    if type(id) ~= 'number' then 
        return false 
    end
    
    local drop = drops[id]
    if not drop then
        return false
    end

    local added = GiveItem(src, drop.item, 1)
    if not added then
        return false
    end

    deleteDrop(id)
    return true
end

local function usePhotolights(source, item)
    local itemConfig = findItemConfig(item.name)
    if itemConfig then
        TriggerClientEvent('hl:photolights:useItem', source, item.slot, itemConfig.model, itemConfig.name)
    end
end

local function startDistanceMonitoring()
    local timeoutMs = (config.DISTANCE_TIMEOUT_MINUTES or DISTANCE_TIMEOUT_DEFAULT) * 60 * 1000
    
    CreateThread(function()
        while true do
            Wait(DISTANCE_CHECK_INTERVAL)
            
            for id, drop in pairs(drops) do
                local ped = GetPlayerPed(drop.owner)
                
                if not ped or not DoesEntityExist(ped) then
                    -- Player disconnected, cleanup drop
                    deleteDrop(id, { giveback = config.GIVEBACK_ON_DESPAWN })
                else
                    local playerCoords = GetEntityCoords(ped)
                    local distance = calculateDistance(playerCoords, drop.position)

                    if distance > config.MAX_DISTANCE then
                        if not drop.outOfRangeAtMs then
                            -- Just went out of range
                            drop.outOfRangeAtMs = nowMs()
                        elseif (nowMs() - drop.outOfRangeAtMs) >= timeoutMs then
                            -- Timeout reached, delete drop
                            deleteDrop(id, { giveback = config.GIVEBACK_ON_DESPAWN })
                        end
                    else
                        -- Back in range, reset timer
                        drop.outOfRangeAtMs = nil
                    end
                end
            end
        end
    end)
end

local function registerUsableItems()
    for _, item in ipairs(config.ITEMS) do
        CreateUsableItem(item.name, usePhotolights)
    end
end

local function registerCallbacks()
    lib.callback.register('hl:photolights:setcolour', function(source, id, data)
        return setColour(source, id, data)
    end)

    lib.callback.register('hl:photolights:dropProp', function(source, itemId, coords, itemName)
        return dropProp(source, itemId, coords, itemName)
    end)

    lib.callback.register('hl:photolights:pickupDrop', function(source, id)
        return pickupDrop(source, id)
    end)
end

local function setupCleanup()
    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName ~= GetCurrentResourceName() then 
            return 
        end
        
        -- Cleanup all drops
        for id, drop in pairs(drops) do
            deleteDrop(id, { giveback = config.GIVEBACK_ON_DESPAWN })
        end
        
        -- Reset counters
        dropIdCounter = 0
        playerDropCounts = {}
        lastActionAtMs = {
            setcolour = {},
            drop = {},
            pickup = {}
        }
    end)
end

-- Initialize
registerUsableItems()
registerCallbacks()
startDistanceMonitoring()
setupCleanup()

-- Exports
exports('setColour', setColour)
exports('dropProp', dropProp)
exports('pickupDrop', pickupDrop)
exports('deleteDrop', deleteDrop)
exports('getDropCount', getCount)