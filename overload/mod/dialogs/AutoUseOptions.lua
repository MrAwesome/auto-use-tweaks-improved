require "engine.class"
local Dialog = require "engine.ui.Dialog"
local TreeList = require "engine.ui.TreeList"
local Textzone = require "engine.ui.Textzone"
local Separator = require "engine.ui.Separator"
local GetQuantity = require "engine.dialogs.GetQuantity"
local Config = require "mod.auto_use.config"

local function getHPOperator(cfg, item, self_ref)
	Dialog:yesnocancelPopup("HP Threshold Override", "Select comparison operator", function(ret, cancel)
		if cancel then return end
		local op = ret and ">" or "<"
		game:registerDialog(GetQuantity.new("Threshold value", "HP % (0-100)", 50, 100, function(qty)
			cfg.hp_custom = {op = op, pct = math.max(0, math.min(100, qty))}
			self_ref:refresh(item)
		end, 0))
	end, "> (above)", "< (below)", "Cancel")
end

module(..., package.seeall, class.inherit(Dialog))

local function cycle3(current, values)
	if current == nil then return values[1] end
	for i, v in ipairs(values) do
		if current == v then
			local next = values[i + 1]
			if next == nil then return nil end
			return next
		end
	end
	return values[1]
end

function _M:init(item)
	local talent_id = item.name
	local display_name = item.display_name or talent_id
	self.talent_id = talent_id
	self.cfg = Config.copy(Config.get(game.player, talent_id))

	Dialog.init(self, display_name .. ": Auto Use Rules", game.w * 0.8, game.h * 0.8)

	self.c_desc = Textzone.new{width=math.floor(self.iw / 2 - 10), height=self.ih, text=""}
	self:generateList()
	self.c_list = TreeList.new{width=math.floor(self.iw / 2 - 10), height=self.ih - 10, scrollbar=true, columns={
		{width=60, display_prop="name"},
		{width=40, display_prop="status"},
	}, tree=self.list, fct=function(item) if item.fct then item.fct(item) end end, select=function(item, sel) self:select(item) end}

	self:loadUI{
		{left=0, top=0, ui=self.c_list},
		{right=0, top=0, ui=self.c_desc},
		{hcenter=0, top=5, ui=Separator.new{dir="horizontal", size=self.ih - 10}},
	}
	self:setFocus(self.c_list)
	self:setupUI()

	self.key:addBinds{
		EXIT = function()
			if self.enable_on_exit then
				Config.enable(game.player, self.talent_id, self.cfg)
			else
				Config.set(game.player, self.talent_id, self.cfg)
			end
			game:unregisterDialog(self)
		end,
	}
end

function _M:select(item)
	if item and self.uis[2] then
		self.uis[2].ui = item.zone
	end
end

function _M:refresh(item)
	self.c_list:drawItem(item)
end

function _M:refreshAll()
	for _, item in ipairs(self.list) do
		self.c_list:drawItem(item)
	end
end

function _M:generateList()
	local cfg = self.cfg
	local list = {}

	local function add(name, desc, status_fn, fct_fn)
		list[#list+1] = {
			zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=desc},
			name = string.toTString("#GOLD##{bold}#"..name.."#{normal}#"),
			status = status_fn,
			fct = fct_fn,
		}
	end

	add("Trigger", "When should this talent fire?\n\n#WHITE#Auto = each turn. Left click = only when you click a hostile target.",
		function() return cfg.trigger == "left_click" and "left click" or "auto" end,
		function(item)
			cfg.trigger = cfg.trigger == "left_click" and "auto" or "left_click"
			self:refresh(item)
		end)

	add("Enemies", "Enemy presence requirement.\n\n#WHITE#Ignore = no check. Require = need visible hostiles. Forbid = no visible hostiles, not blind, not in combat.",
		function()
			if cfg.enemy_presence == "require" then return "require"
			elseif cfg.enemy_presence == "forbid" then return "when safe"
			else return "ignore" end
		end,
		function(item)
			cfg.enemy_presence = cycle3(cfg.enemy_presence, {"require", "forbid"})
			self:refresh(item)
		end)

	add("HP", "Health threshold filter.\n\n#WHITE#Cycle: >80% → <80% → >60% → <60% → ignore. Only fires when your life matches the threshold.\n\n#LIGHT_RED#HP override takes precedence when set.#WHITE#",
		function()
			if not cfg.hp then return "ignore"
			else return ("%s %d%%"):format(cfg.hp.op, cfg.hp.pct) end
		end,
		function(item)
			if not cfg.hp then
				cfg.hp = {op = ">", pct = 80}
			elseif cfg.hp.op == ">" and cfg.hp.pct == 80 then
				cfg.hp = {op = "<", pct = 80}
			elseif cfg.hp.op == "<" and cfg.hp.pct == 80 then
				cfg.hp = {op = ">", pct = 60}
			elseif cfg.hp.op == ">" and cfg.hp.pct == 60 then
				cfg.hp = {op = "<", pct = 60}
			else
				cfg.hp = nil
			end
			self:refresh(item)
		end)

	add("HP override", "Custom HP threshold override.\n\n#WHITE#Choose > or < and type 0-100%. Overrides HP section when set. Click to set, click again to change or clear.",
		function()
			if not cfg.hp_custom then return "none"
			else return ("%s %d%%"):format(cfg.hp_custom.op, cfg.hp_custom.pct) end
		end,
		function(item)
			if not cfg.hp_custom then
				getHPOperator(cfg, item, self)
			else
				Dialog:yesnocancelPopup("HP Override: " .. cfg.hp_custom.op .. " " .. cfg.hp_custom.pct .. "%", "Modify or clear the override?", function(ret, cancel)
					if cancel then
						cfg.hp_custom = nil
						self:refresh(item)
					elseif ret then
						local new_op = cfg.hp_custom.op == ">" and "<" or ">"
						cfg.hp_custom.op = new_op
						self:refresh(item)
					else
						game:registerDialog(GetQuantity.new("Threshold value", "HP % (0-100)", cfg.hp_custom.pct, 100, function(qty)
							cfg.hp_custom.pct = math.max(0, math.min(100, qty))
							self:refresh(item)
						end, 0))
					end
				end, "Toggle op", "Change value", "Clear")
			end
		end)

	add("Range", "Distance to enemies required to fire.\n\n#WHITE#talent_max = within talent range. not_adjacent = ≥2 tiles & in range. two_tiles = ≤2 Chebyshev. melee = adjacent (Chebyshev ≤1).",
		function()
			if not cfg.range or cfg.range == "none" then return "ignore"
			else return cfg.range end
		end,
		function(item)
			cfg.range = cycle3(cfg.range, {"talent_max", "not_adjacent", "two_tiles", "melee"})
			self:refresh(item)
		end)
	add("Distance band", "Override min and max distance to nearest enemy.\n\n#WHITE#Click to set min, then max. Fires only if distance ∈ [min, max]. Works with Range or alone.",
		function()
			if not cfg.distance then return "ignore"
			else return ("(%d, %d)"):format(cfg.distance.min or 1, cfg.distance.max or 10) end
		end,
		function(item)
			if not cfg.distance then
				game:registerDialog(GetQuantity.new("Min distance", "Minimum tiles from enemy", 2, 20, function(qty)
					local new_min = util.bound(qty, 1, 20)
					game:registerDialog(GetQuantity.new("Max distance", "Maximum tiles from enemy", 10, 20, function(qty2)
						cfg.distance = {min = new_min, max = util.bound(qty2, new_min, 20)}
						self:refresh(item)
					end, 1))
				end, 1))
			else
				cfg.distance = nil
				self:refresh(item)
			end
		end)

	add("Elite filter", "Blocks firing when any visible enemy is elite+ (rank > 2).\n\n#WHITE#Ignore = allow all ranks. No elites+ = cancel if any enemy is rank 3+.",
		function() return cfg.enemy_rank_max and "no elites+" or "ignore" end,
		function(item)
			if cfg.enemy_rank_max then
				cfg.enemy_rank_max = nil
			else
				cfg.enemy_rank_max = 2
			end
			self:refresh(item)
		end)

	add("Resting", "Only fire while resting, or only when not resting.",
		function()
			if cfg.resting == true then return "must rest"
			elseif cfg.resting == false then return "not resting"
			else return "ignore" end
		end,
		function(item)
			cfg.resting = cycle3(cfg.resting, {true, false})
			self:refresh(item)
		end)

	add("Sustained", "For sustained talents: turn on when safe, or turn off when enemies appear.",
		function()
			if cfg.sustained == "on_when_safe" then return "on when safe"
			elseif cfg.sustained == "off_when_enemies" then return "off when enemies"
			else return "ignore" end
		end,
		function(item)
			cfg.sustained = cycle3(cfg.sustained, {"on_when_safe", "off_when_enemies"})
			self:refresh(item)
		end)

	add("Debuff", "Effect type requirement.\n\n#WHITE#Ignore = no check. Cycle: physical → mental → magical → any. Fires only when you have a detrimental effect of the chosen type.",
		function()
			if not cfg.effects then return "ignore"
			else return cfg.effects end
		end,
		function(item)
			cfg.effects = cycle3(cfg.effects, {"physical", "mental", "magical", "any"})
			self:refresh(item)
		end)


	add("Reset to defaults", "Reset all rules to defaults for this talent.\n\n#WHITE#Clears all HP, enemies, range, debuff, etc. settings back to their defaults.",
		function() return "click to reset" end,
		function(item)
			Dialog:yesnoPopup("Reset to defaults", "Reset all rules for this talent?", function(ok)
				if ok then
					self.cfg = Config.copy(Config.defaults)
					self.cfg.enabled = true
					self:refreshAll()
				end
			end)
		end)

	self.list = list
end

return _M
