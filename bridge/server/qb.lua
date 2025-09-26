if Config.Framework ~= "QB" then return end

---@param source number
---@param item string
---@param amount? number
---@return boolean
function HasItem(source, item, amount)
    if not amount then amount = 1 end

    if GetResourceState("ox_inventory") == "started" then
        if exports.ox_inventory:Search(source, 'count', item) >= amount then
            return true
        end
    elseif GetResourceState("qb-inventory") == "started" then
        if QBCore.Functions.HasItem(source, item, amount) then
            return true
        end
    end
    
    return false
end

---@param source integer
---@param item string
---@param amount? integer
---@param metadata? table
---@return boolean
function GiveItem(source, item, amount, metadata)
    if not amount then amount = 1 end

    if GetResourceState("ox_inventory") == "started" then
        local success, resp = exports.ox_inventory:AddItem(source, item, amount, metadata)
        if not success then
            Debug("Unable to add item to inventory (" .. resp .. ")", DebugTypes.Error)
        end

        return success
    elseif GetResourceState("qb-inventory") == "started" then
        local player = GetPlayer(source)
        if not player then return false end

        local success = exports['qb-inventory']:AddItem(source, item, amount, false, metadata)

        if not success then
            Debug("Unable to add item to inventory (" .. source .. ")", DebugTypes.Error)
        end
    end

    return false
end

---@param source integer
---@param item string
---@param amount? integer
---@return boolean
function RemoveItem(source, item, amount)
    if not amount then amount = 1 end

    if GetResourceState("ox_inventory") == "started" then
        local success = exports.ox_inventory:RemoveItem(source, item, amount)
        if not success then
            Debug("Unable to remove item from inventory (" .. source .. ")", DebugTypes.Error)
        end

        return success
    elseif GetResourceState("qb-inventory") == "started" then
        local player = GetPlayer(source)
        if not player then return false end

        local success = QBCore.Functions.RemoveItem(player.PlayerData.citizenid, item, amount)

        if not success then
            Debug("Unable to remove item from inventory (" .. source .. ")", DebugTypes.Error)
        end

        return success
    end

    return false
end

---@param item string
---@param itemUse function
function CreateUsableItem(item, itemUse)
    QBCore.Functions.CreateUseableItem(item, itemUse)
end

---@param source integer
---@return table
function GetPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end