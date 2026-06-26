local _M = {}

_M.defaults = {
	enabled = true,
	trigger = "auto",
	enemy_presence = nil,
	hp = nil,
	effects = nil,
	enemy_rank_max = nil,
	distance = nil,
	range = nil,
	resting = nil,
	sustained = nil,
}

function _M.copy(t)
	local u = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			u[k] = _M.copy(v)
		else
			u[k] = v
		end
	end
	return u
end

function _M.merge(base, overrides)
	local out = _M.copy(base)
	if not overrides then return out end
	for k, v in pairs(overrides) do
		if v == false or v == nil then
			out[k] = v
		elseif type(v) == "table" and type(out[k]) == "table" then
			out[k] = _M.merge(out[k], v)
		else
			out[k] = v
		end
	end
	return out
end

local function prefKey(player, talent_id)
	local t = player.talents_def[talent_id]
	if t and t.name then return t.name end
	local o = player:findInAllInventories(talent_id, {no_add_name=true, force_id=true, no_count=true})
	if o and o.use_talent and o.use_talent.id then
		local tt = player.talents_def[o.use_talent.id]
		if tt and tt.name then return tt.name end
		return o.use_talent.id
	end
	return talent_id
end

function _M.defaultsFor(player, talent_id)
	local Prefs = require "mod.auto_use.prefs"
	local pref = Prefs.get(prefKey(player, talent_id))
	if pref then
		local merged = _M.merge(_M.defaults, pref)
		merged.enabled = true
		return merged
	end
	return _M.copy(_M.defaults)
end

function _M.get(player, talent_id)
	player.talents_auto_config = player.talents_auto_config or {}
	local cfg = player.talents_auto_config[talent_id]
	if cfg then
		local merged = _M.merge(_M.defaults, cfg)
		merged.enabled = true
		return merged
	end
	return _M.defaultsFor(player, talent_id)
end

function _M.set(player, talent_id, cfg)
	player.talents_auto_config = player.talents_auto_config or {}
	player.talents_auto_config[talent_id] = _M.copy(cfg)
	local Prefs = require "mod.auto_use.prefs"
	Prefs.set(prefKey(player, talent_id), cfg)
end

function _M.isEnabled(player, talent_id)
	return player.talents_auto and player.talents_auto[talent_id] ~= nil
end

function _M.enable(player, talent_id, cfg)
	player.talents_auto = player.talents_auto or {}
	player.talents_auto[talent_id] = true
	if cfg then
		_M.set(player, talent_id, cfg)
	else
		local existing = player.talents_auto_config and player.talents_auto_config[talent_id]
		if not existing then
			_M.set(player, talent_id, _M.defaultsFor(player, talent_id))
		end
	end
end

function _M.disable(player, talent_id)
	if player.talents_auto then player.talents_auto[talent_id] = nil end
end

return _M
