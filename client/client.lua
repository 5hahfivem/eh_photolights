local functions = {}
local config = require('shared.config')

local drops = {}
local lights = {}
local playerPed <const> = (cache and cache.ped) or PlayerPedId()
local previewProp = nil
local previewActive = false
local previewData = nil
local previewRotation = 0.0
local cooldown = 0

local L = function(key, ...)
	if lib and lib.locale then
		return lib.locale(key, ...)
	end
	return (key):format(...)
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
		SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(entity), false)
	end

	if onCreated then
		onCreated(entity)
	end

	local object = {
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

	return object
end
functions.createObject = createObject

local function RaycastFromCamera(distance)
	local camCoords = GetGameplayCamCoord()
	local camRot = GetGameplayCamRot(2)
	local direction = vector3(
		-math.sin(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
		math.cos(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
		math.sin(math.rad(camRot.x))
	)
	local endCoords = camCoords + direction * distance

	local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, -1, playerPed, 0)
	local _, hit, coords, _, _ = GetShapeTestResult(rayHandle)
	return hit == 1, coords or endCoords
end
functions.RaycastFromCamera = RaycastFromCamera

local function StartPreview(itemId, model, itemName)
	if previewActive or GetGameTimer() < cooldown then
		return false
	end

	previewActive = true
	previewData = { itemId = itemId, model = model, itemName = itemName }
	previewRotation = 0.0

	lib.requestModel(model)
	previewProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
	SetEntityAlpha(previewProp, 128, false)
	SetEntityCollision(previewProp, false, false)
	SetModelAsNoLongerNeeded(model)

	lib.showTextUI(L('interact.place') .. '  ' .. L('interact.cancel'), {
		position = 'bottom-center',
		icon = 'eye',
		iconColor = 'white',
		iconAnimation = 'bounce'
	})

	CreateThread(function()
		while previewActive do
			local hit, coords = RaycastFromCamera(10.0)
			if hit then
				SetEntityCoords(previewProp, coords.x, coords.y, coords.z, false, false, false, false)
				PlaceObjectOnGroundProperly(previewProp)
				SetEntityRotation(previewProp, 0.0, 0.0, previewRotation, 2, false)
			end

			if IsControlJustReleased(0, 23) then
				functions.ConfirmPlacement()
			elseif IsControlJustReleased(0, 47) then
				functions.CancelPlacement()
			end

			if IsControlPressed(0, 14) then
				previewRotation = previewRotation + 5.0
			elseif IsControlPressed(0, 15) then
				previewRotation = previewRotation - 5.0
			end

			Wait(0)
		end
	end)

	return true
end
functions.StartPreview = StartPreview

local function ConfirmPlacement()
	if not previewActive or not previewProp or not previewData then
		return false
	end

	local coords = GetEntityCoords(previewProp)
	local heading = previewRotation
	local itemId = previewData.itemId
	local itemName = previewData.itemName

	DeleteEntity(previewProp)
	previewProp = nil
	previewActive = false
	previewData = nil
	previewRotation = 0.0
	lib.hideTextUI()

	cooldown = GetGameTimer() + 1000
	local ok, err = lib.callback.await('eh:photolights:dropProp', false, itemId, vector4(coords.x, coords.y, coords.z, heading), itemName)
	if not ok and err == 'max_drops' then
		Notify(L('notification.max_drops', tostring(config.MAX_DROPS_PER_PLAYER)), 'error')
	end
	return true
end
functions.ConfirmPlacement = ConfirmPlacement

local function CancelPlacement()
	if not previewActive or not previewProp then
		return false
	end

	DeleteEntity(previewProp)
	previewProp = nil
	previewActive = false
	previewData = nil
	previewRotation = 0.0
	lib.hideTextUI()
	return true
end
functions.CancelPlacement = CancelPlacement

local function RotateLeft()
	if not previewActive or not previewProp then
		return false
	end
	previewRotation = previewRotation + 10.0
	if previewRotation >= 360.0 then
		previewRotation = previewRotation - 360.0
	end
	return true
end
functions.RotateLeft = RotateLeft

local function RotateRight()
	if not previewActive or not previewProp then
		return false
	end
	previewRotation = previewRotation - 10.0
	if previewRotation < 0.0 then
		previewRotation = previewRotation + 360.0
	end
	return true
end
functions.RotateRight = RotateRight

local function UseItem(slot, model, itemName)
	StartPreview(tostring(slot), model, itemName)
end
functions.UseItem = UseItem

local function PickupDrop(data)
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

	lib.callback.await('eh:photolights:pickupDrop', false, state.propDrop.id)
end
functions.PickupDrop = PickupDrop

local function CreateDrop(data)
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
functions.CreateDrop = CreateDrop

local function DeleteDrop(id)
	local drop = drops[id]
	if not drop then
		return
	end

	if drop.object and DoesEntityExist(drop.object.entity) then
		drop.object.remove()
	end

	drops[id] = nil
end
functions.DeleteDrop = DeleteDrop

local function GetLight(id)
	return lights[id]
end
functions.GetLight = GetLight

local function ParseRGB(value)
	local r, g, b = value:match('(%d+),%s*(%d+),%s*(%d+)')
	return {
		red = tonumber(r) or 0,
		green = tonumber(g) or 0,
		blue = tonumber(b) or 0
	}
end
functions.ParseRGB = ParseRGB

local function SetupTarget()
	local models = {}
	for _, item in ipairs(config.ITEMS) do
		table.insert(models, item.model)
	end

	-- Use bridge target abstraction
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

				local colour = ParseRGB(input[1])
				lib.callback.await('eh:photolights:setcolour', false, id, {
					colour = colour,
					label = input[1]
				})
			end
		},
		{
			name = 'pickup',
			onSelect = PickupDrop,
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
functions.SetupTarget = SetupTarget

local function HandleSetColour(id, data)
	local drop = drops[id]
	if not drop then
		return
	end

	Entity(drop.object.entity).state:set('lightcolour', data, true)
	lights[id] = { colour = data.colour, label = data.label }
end
functions.HandleSetColour = HandleSetColour

local function HandleStateBagChange(bagName, _, value)
	local entity = GetEntityFromStateBagName(bagName)
	if not DoesEntityExist(entity) then
		return
	end
	SetObjectLightColor(entity, true, value.colour.red, value.colour.green, value.colour.blue)
end
functions.HandleStateBagChange = HandleStateBagChange

RegisterNetEvent('eh:photolights:drop', CreateDrop)
RegisterNetEvent('eh:photolights:setcolour', HandleSetColour)
RegisterNetEvent('eh:photolights:deleteDrop', DeleteDrop)
RegisterNetEvent('eh:photolights:useItem', function(slot, model, itemName)
	UseItem(slot, model, itemName)
end)
AddStateBagChangeHandler('lightcolour', '', HandleStateBagChange)

exports('getLight', GetLight)

SetupTarget()

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(res)
	if res ~= GetCurrentResourceName() then return end
	if previewActive and previewProp and DoesEntityExist(previewProp) then
		DeleteEntity(previewProp)
	end
	lib.hideTextUI()
	for id, drop in pairs(drops) do
		if drop.object and drop.object.entity and DoesEntityExist(drop.object.entity) then
			drop.object.remove()
		end
		drops[id] = nil
	end
end)

return functions