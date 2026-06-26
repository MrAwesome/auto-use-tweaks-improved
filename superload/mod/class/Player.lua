local _M = loadPrevious(...)

local Config = require "mod.auto_use.config"
local Evaluate = require "mod.auto_use.evaluate"

local left_click_trigger = false
local lc_target = nil
local talents_ran_check = false

function _M:iclicked(a)
	left_click_trigger = true
	lc_target = a
	talents_ran_check = false
end

function _M:checktal()
	return talents_ran_check
end

local function useTalentOrItem(self, tid, inventory, item_name, forcedtarget)
	if inventory then
		game.player:hotkeyInventory(item_name)
	else
		if forcedtarget then
			game.player:useTalent(tid, nil, nil, nil, forcedtarget)
		else
			game.player:useTalent(tid)
		end
	end
end

local function resolveTalent(self, tid)
	local inventory = false
	local item_name = ""
	local t = self.talents_def[tid]
	local range
	if t then return t, tid, inventory, item_name, range end

	local o = game.player:findInAllInventories(tid, {no_add_name=true, force_id=true, no_count=true})
	if o and o.use_talent and o.use_talent.id then
		t = self.talents_def[o.use_talent.id]
		inventory = true
		item_name = tid
		tid = o.use_talent.id
	elseif o and o.use_power then
		t = {name=tid, mode="activated", auto_use_check=false, no_energy=false}
		range = 1
		inventory = true
		item_name = tid
	else
		return nil
	end
	return t, tid, inventory, item_name, range
end

function _M:automaticTalents()
	if self.no_automatic_talents or self.talents_auto_off then return end

	self:attr("_forbid_sounds", 1)
	local uses = {}
	local ctx = Evaluate.buildContext(self, left_click_trigger, lc_target)

	for bind_id, _ in pairs(self.talents_auto or {}) do
		local t, tid, inventory, item_name, range = resolveTalent(self, bind_id)
		if not t then
			self.talents_auto[bind_id] = nil
		else
			range = range or math.max(self:getTalentRange(t), self:getTalentRadius(t))
			local cfg = Config.get(self, bind_id)

			if Evaluate.evaluate(self, cfg, ctx, t, range) then
				local can_use = true
				if t.mode == "sustained" then
					if cfg.sustained == "on_when_safe" and not self.sustain_talents[tid] then
						useTalentOrItem(self, inventory and bind_id or tid, inventory, item_name)
						talents_ran_check = true
						can_use = false
					elseif cfg.sustained == "off_when_enemies" and self.sustain_talents[tid] then
						useTalentOrItem(self, inventory and bind_id or tid, inventory, item_name)
						talents_ran_check = true
						can_use = false
					end
				end
				if can_use
					and (t.mode ~= "sustained" or not self.sustain_talents[tid])
					and not self.talents_cd[tid]
					and self:preUseTalent(t, true, true)
					and (not t.auto_use_check or t.auto_use_check(self, t))
				then
					uses[#uses + 1] = {
						name = t.name,
						no_energy = t.no_energy == true and 0 or 1,
						cd = self:getTalentCooldown(t) or 0,
						tid = tid,
						bind_id = bind_id,
						is_item = inventory,
						item_name = item_name,
						ftarget = lc_target,
					}
				end
			end
		end
	end

	if self.talents_auto_order and not self.talents_auto_ordering_off then
		local uses_by_bind = {}
		local uses_by_tid = {}
		local uses_by_name = {}
		for _, use in ipairs(uses) do
			uses_by_bind[use.bind_id] = use
			uses_by_tid[use.tid] = use
			uses_by_name[use.name] = use
		end
		local sorted_uses = {}
		local seen = {}
		for _, key in ipairs(self.talents_auto_order) do
			local use = uses_by_bind[key] or uses_by_tid[key] or uses_by_name[key]
			if not use then
				local tt = self.talents_def[key]
				if tt then use = uses_by_name[tt.name] end
			end
			if use and not seen[use.bind_id] then
				table.insert(sorted_uses, use)
				seen[use.bind_id] = true
			end
		end
		for _, use in ipairs(uses) do
			if not seen[use.bind_id] then
				table.insert(sorted_uses, use)
				seen[use.bind_id] = true
			end
		end
		uses = sorted_uses
	end

	table.sort(uses, function(a, b)
		if a.no_energy < b.no_energy then return true
		elseif a.no_energy > b.no_energy then return false
		else return a.cd > b.cd end
	end)

	for _, use in ipairs(uses) do
		if left_click_trigger and use.ftarget then
			local click_t = self.talents_def[use.tid]
			if click_t then
				local click_range = math.max(self:getTalentRange(click_t), self:getTalentRadius(click_t))
				if core.fov.distance(self.x, self.y, use.ftarget.x, use.ftarget.y) <= click_range then
					useTalentOrItem(self, use.is_item and use.bind_id or use.tid, use.is_item, use.item_name, use.ftarget)
					talents_ran_check = true
				end
			end
		else
			useTalentOrItem(self, use.is_item and use.bind_id or use.tid, use.is_item, use.item_name)
			talents_ran_check = true
		end
		if use.no_energy == 1 then break end
	end

	lc_target = nil
	left_click_trigger = false
	self:attr("_forbid_sounds", -1)
end

return _M
