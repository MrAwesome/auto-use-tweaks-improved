local _M = {}

local function chebyshev(ax, ay, bx, by)
	return math.max(math.abs(ax - bx), math.abs(ay - by))
end

local function hpMatches(self, hp)
	if not hp or not hp.op or not hp.pct then return true end
	local threshold = self.max_life * hp.pct / 100
	if hp.op == "<" then return self.life < threshold
	elseif hp.op == "<=" then return self.life <= threshold
	elseif hp.op == ">" then return self.life > threshold
	elseif hp.op == ">=" then return self.life >= threshold
	end
	return true
end

local function effectMatches(cfg, ctx)
	if not cfg then return true end
	if cfg == "physical" then return ctx.physical == 1
	elseif cfg == "mental" then return ctx.mental == 1
	elseif cfg == "magical" then return ctx.magical == 1
	elseif cfg == "any" then return ctx.physical == 1 or ctx.mental == 1 or ctx.magical == 1
	end
	return true
end

local function foeMatchesDistance(self, foe, distance)
	local d = chebyshev(self.x, self.y, foe.x, foe.y)
	if distance.min and d < distance.min then return false end
	if distance.max and d > distance.max then return false end
	return true
end

local function foeMatchesRange(self, foe, range_mode, talent_range)
	local dist_euclid = core.fov.distance(self.x, self.y, foe.x, foe.y)
	local dist_cheb = chebyshev(self.x, self.y, foe.x, foe.y)
	if range_mode == "melee" then return dist_cheb <= 1
	elseif range_mode == "two_tiles" then return dist_cheb <= 2
	elseif range_mode == "not_adjacent" then return dist_cheb >= 2 and dist_euclid <= talent_range
	elseif range_mode == "talent_max" then return dist_euclid <= talent_range
	end
	return true
end

function _M.buildContext(self, left_click, lc_target)
	local spotted = {}
	if self.x then
		core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, self.sight or 10, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
			local actor = game.level.map(x, y, game.level.map.ACTOR)
			if actor and self:reactionToward(actor) < 0 and self:canSee(actor) and game.level.map.seens(x, y) then
				spotted[#spotted + 1] = {x=x, y=y, actor=actor}
			end
		end, nil)
	end

	local physical, mental, magical = 0, 0, 0
	for eff_id, p in pairs(self.tmp) do
		local e = self.tempeffect_def[eff_id]
		if e.status == "detrimental" then
			if e.type == "physical" then physical = 1
			elseif e.type == "mental" then mental = 1
			elseif e.type == "magical" then magical = 1
			end
		end
	end

	local max_rank = 0
	for _, foe in pairs(spotted) do
		if foe.actor.rank > max_rank then max_rank = foe.actor.rank end
	end

	return {
		spotted = spotted,
		hp80 = self.max_life / 1.2,
		hp60 = self.max_life / 1.65,
		physical = physical,
		mental = mental,
		magical = magical,
		max_rank = max_rank,
		left_click = left_click,
		lc_target = lc_target,
	}
end

function _M.isSafe(self, ctx)
	if #ctx.spotted > 0 or self:attr("blind") then return false end
	if self.in_combat then return false end
	return true
end

function _M.evaluate(self, cfg, ctx, talent, talent_range)
	if not cfg or not cfg.enabled then return false end

	if cfg.trigger == "left_click" then
		if not ctx.left_click then return false end
	elseif cfg.trigger == "auto" then
		if ctx.left_click then return false end
	end

	if cfg.resting == true and not self.resting then return false end
	if cfg.resting == false and self.resting then return false end

	if cfg.enemy_presence == "require" and #ctx.spotted == 0 then return false end
	if cfg.enemy_presence == "forbid" and not _M.isSafe(self, ctx) then return false end

	if not hpMatches(self, cfg.hp) then return false end
	if not effectMatches(cfg.effects, ctx) then return false end

	if cfg.enemy_rank_max and #ctx.spotted > 0 and ctx.max_rank > cfg.enemy_rank_max then
		return false
	end

	if talent.mode == "sustained" then
		if cfg.sustained == "on_when_safe" then
			if self.sustain_talents[talent.id] then return false end
			if not _M.isSafe(self, ctx) then return false end
			return true
		elseif cfg.sustained == "off_when_enemies" then
			if not self.sustain_talents[talent.id] then return false end
			if #ctx.spotted > 0 then return true end
			return false
		end
	end

	if cfg.range and cfg.range ~= "none" and #ctx.spotted == 0 then
		return false
	end

	if cfg.range and cfg.range ~= "none" then
		local matched = false
		for _, foe in pairs(ctx.spotted) do
			if cfg.distance and not foeMatchesDistance(self, foe, cfg.distance) then
			elseif not foeMatchesRange(self, foe, cfg.range, talent_range) then
			elseif cfg.enemy_rank_max and foe.actor.rank > cfg.enemy_rank_max then
			else
				matched = true
				break
			end
		end
		if not matched then return false end
	elseif cfg.distance and #ctx.spotted > 0 then
		local matched = false
		for _, foe in pairs(ctx.spotted) do
			if foeMatchesDistance(self, foe, cfg.distance) then
				matched = true
				break
			end
		end
		if not matched then return false end
	end

	return true
end

return _M
