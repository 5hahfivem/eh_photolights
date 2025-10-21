DebugTypes = {
	Info = "info",
	Warn = "warn",
	Error = "error"
}

function Debug(message, type)
	if type == DebugTypes.Error then
		print(("^1[hl_photolights]^7 %s"):format(message))
	elseif type == DebugTypes.Warn then
		print(("^3[hl_photolights]^7 %s"):format(message))
	else
		print(("^2[hl_photolights]^7 %s"):format(message))
	end
end 