local _M = {}

local function desc(val, label)
	if val == nil then return nil end
	return label
end

function _M.describe(cfg)
	if not cfg then return "Off" end
	local parts = {}

	if cfg.enabled == false then return "Disabled" end
	if cfg.trigger == "left_click" then parts[#parts + 1] = "L-click" end

	if cfg.resting == true then parts[#parts + 1] = "resting"
	elseif cfg.resting == false then parts[#parts + 1] = "not resting" end

	if cfg.enemy_presence == "require" then
		if cfg.range == "melee" then parts[#parts + 1] = "adjacent enemy"
		elseif cfg.range == "two_tiles" then parts[#parts + 1] = "enemy ≤2"
		elseif cfg.range == "not_adjacent" then parts[#parts + 1] = "enemy ≥2"
		elseif cfg.range == "talent_max" then parts[#parts + 1] = "enemy in range"
		else parts[#parts + 1] = "enemies" end
	elseif cfg.enemy_presence == "forbid" then
		parts[#parts + 1] = "safe"
	elseif cfg.range then
		if cfg.range == "melee" then parts[#parts + 1] = "adjacent"
		elseif cfg.range == "two_tiles" then parts[#parts + 1] = "≤2 tiles"
		elseif cfg.range == "not_adjacent" then parts[#parts + 1] = "≥2 tiles"
		elseif cfg.range == "talent_max" then parts[#parts + 1] = "in talent range" end
	end

	if cfg.distance then
		if cfg.distance.min then parts[#parts + 1] = ("dist≥%d"):format(cfg.distance.min) end
		if cfg.distance.max then parts[#parts + 1] = ("dist≤%d"):format(cfg.distance.max) end
	end

	if cfg.hp_custom then
		local label = ("HP%s%d%%"):format(cfg.hp_custom.op, cfg.hp_custom.pct)
		parts[#parts + 1] = label
	elseif cfg.hp then
		local label = ("HP%s%d%%"):format(cfg.hp.op, cfg.hp.pct)
		parts[#parts + 1] = label
	end

	if cfg.effects == "any" then parts[#parts + 1] = "any effect"
	elseif cfg.effects == "physical" then parts[#parts + 1] = "physical effect"
	elseif cfg.effects == "mental" then parts[#parts + 1] = "mental effect"
	elseif cfg.effects == "magical" then parts[#parts + 1] = "magical effect"
	end

	if cfg.enemy_rank_max then parts[#parts + 1] = ("no elite+") end

	if cfg.sustained == "on_when_safe" then parts[#parts + 1] = "activate when safe"
	elseif cfg.sustained == "off_when_enemies" then parts[#parts + 1] = "deactivate w/ enemies"
	end

	if #parts == 0 then return "Available"
	elseif #parts == 1 then return parts[1] end
	return table.concat(parts, " / ")
end

return _M
