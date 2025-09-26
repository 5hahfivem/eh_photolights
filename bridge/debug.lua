DebugTypes = {
	Info = "info",
	Warn = "warn",
	Error = "error"
}

function Debug(message, type)
	if type == DebugTypes.Error then
		print(("^1[eh_photolights]^7 %s"):format(message))
	elseif type == DebugTypes.Warn then
		print(("^3[eh_photolights]^7 %s"):format(message))
	else
		print(("^2[eh_photolights]^7 %s"):format(message))
	end
end 