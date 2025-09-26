if Config.Framework ~= "Mythic" then return end

local function retrieveComponents()
	Database = exports["mythic-base"]:FetchComponent("Database")
	Logger = exports["mythic-base"]:FetchComponent("Logger")
	Fetch = exports["mythic-base"]:FetchComponent("Fetch")
	Inventory = exports["mythic-base"]:FetchComponent("Inventory")
	Wallet = exports["mythic-base"]:FetchComponent("Wallet")
	Banking = exports["mythic-base"]:FetchComponent("Banking")
	Execute = exports["mythic-base"]:FetchComponent("Execute")
	Jobs = exports["mythic-base"]:FetchComponent("Jobs")
	Crypto = exports["mythic-base"]:FetchComponent("Crypto")
	Vehicles = exports["mythic-base"]:FetchComponent("Vehicles")
end

AddEventHandler("eh_photolights:Shared:DependencyUpdate", retrieveComponents)

AddEventHandler("Core:Shared:Ready", function()
	exports["mythic-base"]:RequestDependencies("eh_photolights", {
		"Database",
		"Logger",
		"Fetch",
		"Inventory",
		"Wallet",
		"Banking",
		"Execute",
		"Jobs",
		"Crypto",
		"Vehicles"
	}, function(error)
		if #error > 0 then
			Logger:Critical("eh_photolights", "Failed To Load All Dependencies")
			return
		end

		retrieveComponents()
	end)
end)

---@param source number
---@param item string
---@param amount? number
---@return boolean
function HasItem(source, item, amount)
    if not amount then amount = 1 end

	local char = Fetch:Source(source):GetData("Character")
	local count = Inventory.Items:GetCount(char:GetData("SID"), 1, item)

    if count < amount then
		Debug(("Not enough of %s in inventory"):format(item), DebugTypes.Info)
        return false
    end
    
    return true
end

---@param source number
---@param item string
---@param amount? number
---@return boolean
function GiveItem(source, item, amount)
    if not amount then amount = 1 end
	local char = Fetch:Source(source):GetData("Character")
	return Inventory:AddItem(char:GetData("SID"), item, amount, {}, 1)
end

---@param source number
---@param item string
---@param amount? number
---@return boolean
function RemoveItem(source, item, amount)
    if not amount then amount = 1 end
	local char = Fetch:Source(source):GetData("Character")
	return Inventory.Items:Remove(char:GetData("SID"), 1, item, amount)
end

---@param item string
---@param itemUse function
function CreateUsableItem(item, itemUse)
	Inventory.Items:RegisterUse(item, "eh_photolights", function(source, item)
		itemUse(source, item)
	end)
end

---@param source number
---@return table
function GetPlayer(source)
	return Fetch:Source(source)
end