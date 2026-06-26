local Config = require "mod.auto_use.config"

local _M = {}

local SETTINGS_KEY = "talent_prefs"

local function ensure()
	config.settings.tome = config.settings.tome or {}
	config.settings.tome.auto_use_tweaks = config.settings.tome.auto_use_tweaks or {}
	config.settings.tome.auto_use_tweaks[SETTINGS_KEY] = config.settings.tome.auto_use_tweaks[SETTINGS_KEY] or {}
	return config.settings.tome.auto_use_tweaks[SETTINGS_KEY]
end

function _M.get(talent_id)
	return ensure()[talent_id]
end

function _M.set(talent_id, cfg)
	ensure()[talent_id] = Config.copy(cfg)
	_M.save()
end

local function serializeValue(v)
	local t = type(v)
	if t == "string" then return ("%q"):format(v)
	elseif t == "number" then return tostring(v)
	elseif t == "boolean" then return v and "true" or "false"
	elseif t == "table" then
		local inner = {}
		for k, val in pairs(v) do
			if type(k) == "string" then
				inner[#inner + 1] = ("%s = %s"):format(k, serializeValue(val))
			else
				inner[#inner + 1] = ("[%d] = %s"):format(k, serializeValue(val))
			end
		end
		return "{ " .. table.concat(inner, ", ") .. " }"
	end
	return "nil"
end

function _M.save()
	if not game then return end
	local prefs = ensure()
	local parts = { "tome.auto_use_tweaks.talent_prefs = {\n" }
	for tid, cfg in pairs(prefs) do
		local inner = {}
		for k, v in pairs(cfg) do
			if k ~= "enabled" then
				inner[#inner + 1] = ("%s = %s"):format(k, serializeValue(v))
			end
		end
		parts[#parts + 1] = ("\t[%q] = { %s },\n"):format(tid, table.concat(inner, ", "))
	end
	parts[#parts + 1] = "}\n"
	game:saveSettings("tome.auto_use_tweaks.talent_prefs", table.concat(parts))
end

return _M
