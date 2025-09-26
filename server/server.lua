local functions = {}
local config = require('shared.config')

local drops = {}
local dropIdCounter = 0
local playerDropCounts = {}

-- simple rate limiting per player per action
local lastActionAtMs = {
	setcolour = {},
	drop = {},
	pickup = {}
}

local function nowMs()
	return GetGameTimer()
end

local function isThrottled(bucket, src, cooldownMs)
	local last = lastActionAtMs[bucket][src]
	if last and (nowMs() - last) < cooldownMs then
		return true
	end
	lastActionAtMs[bucket][src] = nowMs()
	return false
end

local function clamp(n, min, max)
	if n < min then return min end
	if n > max then return max end
	return n
end

local function validateAndClampColour(data)
	if type(data) ~= 'table' or type(data.colour) ~= 'table' then
		return nil
	end
	local c = data.colour
	local r = tonumber(c.red)
	local g = tonumber(c.green)
	local b = tonumber(c.blue)
	if not r or not g or not b then return nil end
	return {
		colour = {
			red = clamp(r, 0, 255),
			green = clamp(g, 0, 255),
			blue = clamp(b, 0, 255)
		},
		label = type(data.label) == 'string' and data.label or ("rgb(%d, %d, %d)"):format(clamp(r,0,255), clamp(g,0,255), clamp(b,0,255))
	}
end

local function incrementCount(src)
	playerDropCounts[src] = (playerDropCounts[src] or 0) + 1
end

local function decrementCount(src)
	if not playerDropCounts[src] then return end
	playerDropCounts[src] = math.max(0, playerDropCounts[src] - 1)
	if playerDropCounts[src] == 0 then playerDropCounts[src] = nil end
end

local function getCount(src)
	return playerDropCounts[src] or 0
end

local function SetColour(src, id, data)
	if isThrottled('setcolour', src, 500) then return false end
	if type(id) ~= 'number' then return false end
	local validated = validateAndClampColour(data)
	if not validated then return false end

	local drop = drops[id]
	if not drop then
		return false
	end

	drop.light = validated
	TriggerClientEvent('eh:photolights:setcolour', -1, id, validated)
	return true
end
functions.SetColour = SetColour

local function DeleteDrop(id, opts)
	local drop = drops[id]
	if not drop then return end
	drops[id] = nil
	decrementCount(drop.owner)
	TriggerClientEvent('eh:photolights:deleteDrop', -1, id)
	if opts and opts.giveback and config.GIVEBACK_ON_DESPAWN then
		GiveItem(drop.owner, drop.item, 1)
	end
end

local function DropProp(src, itemId, coords, itemName)
	if isThrottled('drop', src, 750) then return false end
	if type(itemId) ~= 'string' or type(itemName) ~= 'string' then return false end
	if type(coords) ~= 'vector4' and (type(coords) ~= 'table' or coords.x == nil or coords.y == nil or coords.z == nil or coords.w == nil) then return false end

	if getCount(src) >= (config.MAX_DROPS_PER_PLAYER or 5) then
		return false, 'max_drops'
	end

	local itemConfig = nil
	for _, item in ipairs(config.ITEMS) do
		if item.name == itemName then
			itemConfig = item
			break
		end
	end
	if not itemConfig then
		return false
	end

	local removed = RemoveItem(src, itemName, 1)
	if not removed then
		return false
	end

	dropIdCounter = dropIdCounter + 1
	local id = dropIdCounter

	local position = type(coords) == 'vector4' and coords or vector4(coords.x, coords.y, coords.z, coords.w)

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
	TriggerClientEvent('eh:photolights:drop', -1, data)

	SetTimeout(config.DROP_LIFETIME * 60 * 1000, function()
		DeleteDrop(id)
	end)

	return true
end
functions.DropProp = DropProp

local function PickupDrop(src, id)
	if isThrottled('pickup', src, 500) then return false end
	if type(id) ~= 'number' then return false end
	local drop = drops[id]
	if not drop then
		return false
	end

	local added = GiveItem(src, drop.item, 1)
	if not added then
		return false
	end

	drops[id] = nil
	decrementCount(drop.owner)
	TriggerClientEvent('eh:photolights:deleteDrop', -1, id)
	return true
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
	CreateUsableItem(item.name, UsePhotolights)
end

-- ox_lib callbacks
lib.callback.register('eh:photolights:setcolour', function(source, id, data)
	return SetColour(source, id, data)
end)

lib.callback.register('eh:photolights:dropProp', function(source, itemId, coords, itemName)
	return DropProp(source, itemId, coords, itemName)
end)

lib.callback.register('eh:photolights:pickupDrop', function(source, id)
	return PickupDrop(source, id)
end)

CreateThread(function()
	local timeoutMs = (config.DISTANCE_TIMEOUT_MINUTES or 15) * 60 * 1000
	while true do
		Wait(10 * 1000)
		for id, drop in pairs(drops) do
			local ped = GetPlayerPed(drop.owner)
			if not ped or not DoesEntityExist(ped) then
				DeleteDrop(id, { giveback = true })
			else
				local playerCoords = GetEntityCoords(ped)
				local dx, dy, dz = playerCoords.x - drop.position.x, playerCoords.y - drop.position.y, playerCoords.z - drop.position.z
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

				if distance > config.MAX_DISTANCE then
					if not drop.outOfRangeAtMs then
						drop.outOfRangeAtMs = nowMs()
					elseif (nowMs() - drop.outOfRangeAtMs) >= timeoutMs then
						DeleteDrop(id, { giveback = true })
					end
				else
					drop.outOfRangeAtMs = nil
				end
			end
		end
	end
end)

return functions