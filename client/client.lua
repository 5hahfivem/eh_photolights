local config = require('shared.config')

-- Initialize ox_lib locale
lib.locale()

-- Constants
local CONTROL_KEYS = {
    PLACE = 23,      -- E
    CANCEL = 47,     -- G
    ROTATE_LEFT = 14, -- Mouse wheel up
    ROTATE_RIGHT = 15 -- Mouse wheel down
}

local ROTATION_SPEED = 5.0
local PREVIEW_DISTANCE = 10.0
local PREVIEW_ALPHA = 128
local COOLDOWN_TIME = 1000

-- Cache natives
local GetEntityCoords = GetEntityCoords
local GetGameplayCamCoord = GetGameplayCamCoord
local GetGameplayCamRot = GetGameplayCamRot
local StartShapeTestRay = StartShapeTestRay
local GetShapeTestResult = GetShapeTestResult
local CreateObject = CreateObject
local SetEntityCoords = SetEntityCoords
local SetEntityRotation = SetEntityRotation
local SetEntityAlpha = SetEntityAlpha
local SetEntityCollision = SetEntityCollision
local PlaceObjectOnGroundProperly = PlaceObjectOnGroundProperly
local DeleteEntity = DeleteEntity
local DoesEntityExist = DoesEntityExist
local IsControlJustReleased = IsControlJustReleased
local IsControlPressed = IsControlPressed
local GetGameTimer = GetGameTimer
local IsModelValid = IsModelValid
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local SetNetworkIdCanMigrate = SetNetworkIdCanMigrate
local SetModelAsNoLongerNeeded = SetModelAsNoLongerNeeded
local FreezeEntityPosition = FreezeEntityPosition
local SetObjectForceVehiclesToAvoid = SetObjectForceVehiclesToAvoid
local SetObjectLightColor = SetObjectLightColor
local GetEntityFromStateBagName = GetEntityFromStateBagName
local TaskPlayAnim = TaskPlayAnim
local Wait = Wait

-- State management
---@type table<number, any>
local drops = {}
---@type table<number, any>
local lights = {}
local previewActive = false
local previewProp = nil
local previewData = nil
local previewRotation = 0.0
local cooldown = 0

-- Distance warning system
local distanceWarningActive = false
local distanceWarningEndTime = 0
local wasInRange = true

-- Cache player ped
local playerPed <const> = cache.ped

-- Locale helper
local function L(key, ...)
    return locale(key, ...)
end

-- Forward declarations
local confirmPlacement
local cancelPlacement
local cleanupPreview

local function normalizeAngle(angle)
    while angle >= 360.0 do
        angle = angle - 360.0
    end
    while angle < 0.0 do
        angle = angle + 360.0
    end
    return angle
end

local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

local function checkPlayerDistance(playerCoords)
    local closestDistance = math.huge
    local hasLights = false
    
    for _, drop in pairs(drops) do
        if drop.object and DoesEntityExist(drop.object.entity) then
            hasLights = true
            local dropCoords = GetEntityCoords(drop.object.entity)
            local distance = #(playerCoords - dropCoords)
            closestDistance = math.min(closestDistance, distance)
        end
    end
    
    return hasLights, closestDistance
end

local function updateDistanceWarning(playerCoords)
    local hasLights, closestDistance = checkPlayerDistance(playerCoords)
    
    if not hasLights then
        if distanceWarningActive then
            distanceWarningActive = false
            wasInRange = true
        end
        return
    end
    
    local isInRange = closestDistance <= config.MAX_DISTANCE
    local currentTime = GetGameTimer()
    
    if not isInRange then
        -- Player is out of range
        if wasInRange then
            -- Just went out of range, start warning
            distanceWarningActive = true
            distanceWarningEndTime = currentTime + (config.DISTANCE_TIMEOUT_MINUTES * 60 * 1000)
            wasInRange = false
        elseif distanceWarningActive then
            -- Still out of range, update countdown
            local remainingTime = math.max(0, distanceWarningEndTime - currentTime)
            local remainingSeconds = math.ceil(remainingTime / 1000)
            
            if remainingSeconds > 0 then
                local timeString = formatTime(remainingSeconds)
                Notify(L('notification.distance_warning', timeString), 'warning')
            end
        end
    else
        -- Player is back in range
        if not wasInRange then
            -- Just came back in range
            distanceWarningActive = false
            wasInRange = true
            Notify(L('notification.distance_safe'), 'success')
        end
    end
end

---@param distance number
---@return boolean, vector3
local function raycastFromCamera(distance)
    local hit, _, endCoords = lib.raycast.fromCamera(511, 4, distance)
    return hit, endCoords
end


local function createObject(config)
    local model = config.model
    local coords = config.coords
    local networked = config.networked or false
    local onCreated = config.onCreated
    local onDeleted = config.onDeleted

    lib.requestModel(model)
    local entity = CreateObject(model, coords.x, coords.y, coords.z, networked, false, false)
    SetModelAsNoLongerNeeded(model)

    if not DoesEntityExist(entity) then
        return nil
    end

    if networked then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        SetNetworkIdCanMigrate(netId, false)
    end

    if onCreated then
        onCreated(entity)
    end

    return {
        entity = entity,
        remove = function()
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
            if onDeleted then
                onDeleted(entity)
            end
        end
    }
end

local function parseRGB(value)
    local r, g, b = value:match('(%d+),%s*(%d+),%s*(%d+)')
    return {
        red = tonumber(r) or 0,
        green = tonumber(g) or 0,
        blue = tonumber(b) or 0
    }
end

-- Preview system
---@param itemId string
---@param model number
---@param itemName string
---@return boolean
local function startPreview(itemId, model, itemName)
    if previewActive or GetGameTimer() < cooldown then
        return false
    end

    previewActive = true
    previewData = { itemId = itemId, model = model, itemName = itemName }
    previewRotation = 0.0

    lib.requestModel(model)
    previewProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(previewProp, PREVIEW_ALPHA, false)
    SetEntityCollision(previewProp, false, false)
    SetModelAsNoLongerNeeded(model)

    local placeText = L('interact.place')
    local cancelText = L('interact.cancel')
    local rotateText = L('interact.rotate')
    
    lib.showTextUI(placeText .. ' | ' .. cancelText .. ' | ' .. rotateText, {
        position = 'bottom-center',
        icon = 'eye',
        iconColor = 'white',
        iconAnimation = 'bounce'
    })

    CreateThread(function()
        while previewActive do
            local hit, coords = raycastFromCamera(PREVIEW_DISTANCE)
            if hit then
                SetEntityCoords(previewProp, coords.x, coords.y, coords.z, false, false, false, false)
                PlaceObjectOnGroundProperly(previewProp)
                SetEntityRotation(previewProp, 0.0, 0.0, previewRotation, 2, false)
            end

            if IsControlJustReleased(0, CONTROL_KEYS.PLACE) then
                confirmPlacement()
            elseif IsControlJustReleased(0, CONTROL_KEYS.CANCEL) then
                cancelPlacement()
            end

            if IsControlPressed(0, CONTROL_KEYS.ROTATE_LEFT) then
                previewRotation = normalizeAngle(previewRotation + ROTATION_SPEED)
            elseif IsControlPressed(0, CONTROL_KEYS.ROTATE_RIGHT) then
                previewRotation = normalizeAngle(previewRotation - ROTATION_SPEED)
            end

            Wait(0)
        end
    end)

    return true
end

confirmPlacement = function()
    if not previewActive or not previewProp or not previewData then
        return false
    end

    local coords = GetEntityCoords(previewProp)
    local heading = previewRotation
    local itemId = previewData.itemId
    local itemName = previewData.itemName

    cleanupPreview()

    cooldown = GetGameTimer() + COOLDOWN_TIME
    local ok, err = lib.callback.await('hl:photolights:dropProp', false, itemId, vector4(coords.x, coords.y, coords.z, heading), itemName)
    
    if not ok and err == 'max_drops' then
        Notify(L('notification.max_drops', tostring(config.MAX_DROPS_PER_PLAYER)), 'error')
    end
    
    return true
end

cancelPlacement = function()
    if not previewActive or not previewProp then
        return false
    end

    cleanupPreview()
    return true
end

cleanupPreview = function()
    if previewProp and DoesEntityExist(previewProp) then
        DeleteEntity(previewProp)
    end
    
    previewProp = nil
    previewActive = false
    previewData = nil
    previewRotation = 0.0
    lib.hideTextUI()
end

-- Drop management
---@param data table
local function createDrop(data)
    if drops[data.id] then
        return
    end

    if not IsModelValid(data.model) then
        return
    end

    data.object = createObject({
        model = data.model,
        coords = data.position,
        networked = true,
        onCreated = function(entity)
            PlaceObjectOnGroundProperly(entity)
            FreezeEntityPosition(entity, true)
            SetObjectForceVehiclesToAvoid(entity, true)
            SetEntityRotation(entity, 0.0, 0.0, data.position.w, 2, false)

            Entity(entity).state:set('propDrop', {
                id = data.id,
                itemId = data.itemId,
                model = data.model
            }, true)

            if data.light then
                Entity(entity).state:set('lightcolour', data.light, true)
            end
        end,
        onDeleted = function(entity)
            RemoveTargetEntity(entity)
        end
    })

    if not data.object then
        return
    end

    drops[data.id] = data
end

local function deleteDrop(id)
    local drop = drops[id]
    if not drop then
        return
    end

    if drop.object and DoesEntityExist(drop.object.entity) then
        drop.object.remove()
    end

    drops[id] = nil
end

local function pickupDrop(data)
    local entity = data.entity
    if not DoesEntityExist(entity) then
        return
    end

    local state = Entity(entity).state
    if not state.propDrop then
        return
    end

    lib.requestAnimDict('random@domestic')
    TaskPlayAnim(playerPed, 'random@domestic', 'pickup_low', 5.0, 1.0, 1.0, 48, 0.0, false, false, false)
    Wait(400)
    RemoveAnimDict('random@domestic')

    lib.callback.await('hl:photolights:pickupDrop', false, state.propDrop.id)
end

-- Light management
local function handleSetColour(id, data)
    local drop = drops[id]
    if not drop then
        return
    end

    Entity(drop.object.entity).state:set('lightcolour', data, true)
    lights[id] = { colour = data.colour, label = data.label }
end

local function handleStateBagChange(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) then
        return
    end
    
    SetObjectLightColor(entity, true, value.colour.red, value.colour.green, value.colour.blue)
end

local function getLight(id)
    return lights[id]
end

local function setupTarget()
    local models = {}
    for _, item in ipairs(config.ITEMS) do
        models[#models + 1] = item.model
    end

    AddModelTarget(models, {
        {
            name = 'changelight',
            label = L('target.change_colour'),
            icon = 'fa-solid fa-palette',
            distance = 1.0,
            canInteract = function(entity)
                return Entity(entity).state.propDrop ~= nil
            end,
            onSelect = function(data)
                local id = Entity(data.entity).state.propDrop.id
                local input = lib.inputDialog('RGB Controller', {
                    {
                        type = 'color',
                        label = 'Colour',
                        required = true,
                        format = 'rgb',
                        default = lights[id] and lights[id].label or 'rgb(0, 0, 0)'
                    }
                })

                if not input then
                    return
                end

                local colour = parseRGB(input[1])
                lib.callback.await('hl:photolights:setcolour', false, id, {
                    colour = colour,
                    label = input[1]
                })
            end
        },
        {
            name = 'pickup',
            onSelect = pickupDrop,
            label = L('target.pickup'),
            icon = 'fa-solid fa-hand',
            distance = 1.5,
            canInteract = function(entity)
                return Entity(entity).state.propDrop ~= nil
            end,
            drawSprite = true
        }
    })
end

-- Item usage
local function useItem(slot, model, itemName)
    startPreview(tostring(slot), model, itemName)
end

-- Event handlers
RegisterNetEvent('hl:photolights:drop', createDrop)
RegisterNetEvent('hl:photolights:setcolour', handleSetColour)
RegisterNetEvent('hl:photolights:deleteDrop', deleteDrop)
RegisterNetEvent('hl:photolights:useItem', function(slot, model, itemName)
    useItem(slot, model, itemName)
end)

AddStateBagChangeHandler('lightcolour', '', handleStateBagChange)

-- Exports
exports('getLight', getLight)

-- Initialize
setupTarget()

CreateThread(function()
    while true do
        updateDistanceWarning(GetEntityCoords(playerPed))
        Wait(5000)
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then 
        return 
    end
    
    cleanupPreview()
    
    -- Reset distance warning state
    distanceWarningActive = false
    wasInRange = true
    
    for id, drop in pairs(drops) do
        if drop.object and DoesEntityExist(drop.object.entity) then
            drop.object.remove()
        end
        drops[id] = nil
    end
end)