if Config.Framework ~= "Qbox" then return end

---@param source number
---@param item string
---@param amount? number
---@return boolean
function HasItem(source, item, amount)
    if not amount then amount = 1 end
    if exports.ox_inventory:Search(source, 'count', item) >= amount then
        return true
    end

    return false
end

---@param source integer
---@param item string
---@param amount? integer
---@param metadata? integer
---@return boolean
function GiveItem(source, item, amount, metadata)
    if not amount then amount = 1 end
    local success, resp = exports.ox_inventory:AddItem(source, item, amount, metadata)
    if not success then
        Debug("Unable to add item to inventory (" .. resp .. ")", DebugTypes.Error)
    end

    return success
end

---@param source integer
---@param item string
---@param amount? integer
---@return boolean
function RemoveItem(source, item, amount)
    if not amount then amount = 1 end
    local success = exports.ox_inventory:RemoveItem(source, item, amount)
    if not success then
        Debug("Unable to remove item from inventory (" .. source .. ")", DebugTypes.Error)
    end

    return success
end


---@param item string
---@param itemUse function
function CreateUsableItem(item, itemUse)
    exports.qbx_core:CreateUseableItem(item, function(source, item)
        itemUse(source, item)
    end)
end

---@param source integer
---@return table
function GetPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end