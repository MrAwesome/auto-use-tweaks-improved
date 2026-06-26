local _M = loadPrevious(...)

local Dialog = require "engine.ui.Dialog"
local Config = require "mod.auto_use.config"
local Summary = require "mod.auto_use.summary"

function _M:checkSetTalentAuto(tid, v, cfg)
	local inventory = false
	local t = self:getTalentFromId(tid)
	if not t then
		local o = game.player:findInAllInventories(tid, {no_add_name=true, force_id=true, no_count=true})
		if o and o.use_talent and o.use_talent.id then
			t = game.player:getTalentFromId(o.use_talent.id)
		elseif o and o.use_power then
			t = {name=tid, no_energy=false, requires_target=false, auto_use_warning=false}
		end
		inventory = true
	end
	if not t then return end

	local display_name = t.name and t.name:capitalize() or tostring(tid)

	if v then
		local resolved = cfg or Config.get(self, tid)
		local doit = function()
			Config.enable(self, tid, resolved)
			Dialog:simplePopup("Automatic use enabled", display_name.." will auto-use when:\n"..Summary.describe(resolved))
		end

		local list = {}
		if t.no_energy ~= true then list[#list+1] = "- requires a turn to use" end
		if t.requires_target then list[#list+1] = "- requires a target" end
		if t.auto_use_warning then list[#list+1] = t.auto_use_warning end
		list[#list+1] = "- "..Summary.describe(resolved)

		if #list <= 1 then
			doit()
		else
			Dialog:yesnoLongPopup("Automatic use", display_name..":\n"..table.concat(list, "\n").."\n Are you sure?", 500, function(ret)
				if ret then doit() end
			end)
		end
	else
		Config.disable(self, tid)
		Dialog:simplePopup("Automatic use disabled", display_name.." will not be automatically used.")
	end
end

return _M
