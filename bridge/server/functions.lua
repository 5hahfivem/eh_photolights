---@param source integer
---@param message string
---@param type 'inform' | 'error' | 'success' | 'warning'
---@param time? integer
---@param icon? string
function Notify(source, message, type, time, icon)
    TriggerClientEvent("hl_photolights:client:notify", source, message, type, time, icon)
end
