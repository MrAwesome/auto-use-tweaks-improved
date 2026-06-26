# Auto Use Tweaks — Performance Bugs

All perf bugs are in `superload/mod/class/Player.lua` in the `automaticTalents()` function. This runs every player tick — every move, every action. Overhead here is multiplied by game speed.

The original ToME `Player:automaticTalents()` (`tome/class/Player.lua:959-1005`) is already loop-heavy — it calls `spotHostiles()` per talent. The addon's version keeps that pattern and adds substantially more work per talent.

---

## P1. `spotHostiles()` called per talent (repeated FOV calc)

**Line 139** — `spotHostiles(self)` is called **inside** the `for tid, c in pairs(self.talents_auto)` loop, inside the `if t then` guard. Since `spotted` doesn't change within one tick, this is called N times for N auto-use talents.

`spotHostiles` wraps `core.fov.calc_circle` — a C-level function that scans every tile in sight radius (~314 tiles at sight=10). With 15-20 auto talents (common for late-game characters), this runs 15-20 FOV passes per tick instead of 1.

The original engine code had the same bug, but the addon makes it worse by adding much more per-talent work (see P2–P4).

**Fix:** Lift `spotHostiles()` before the talent loop:

```lua
local spotted = spotHostiles(self)
for tid, c in pairs(self.talents_auto) do
```

---

## P2. Effect-scan and max-rank loops run per talent

**Lines 154-158** — iterating `spotted` to find `max_rank`:\
**Lines 159-170** — iterating `self.tmp` to check detrimental effects:

These produce the same result every time within a single tick. With 20 talents and 10 spotted foes: 200 iterations instead of 10.

**Fix:** Lift both before the talent loop, same as P1.

---

## P3. Second `calc_circle` in "can attack this turn" block

**Line 272** — For talents with auto-use modes 50 or 150, `automaticTalents` does a **second** FOV pass via `core.fov.calc_circle`. This one discards results (the callback only sets a local `proj` that isn't captured — see functional bug #1).

Every tick where any talent has c=50 or c=150 triggers this extra O(sight²) pass. Combined with P1, that's 2× FOV passes per affected talent.

**Fix:** Remove the second `calc_circle` call (it's already broken — see functional bug #1). If projectile detection is desired, do it in a single pass merged with `spotHostiles`.

---

## P4. Redundant `spotted` iterations inside the "ranged sanity checks" block

**Lines 339-352** — Three sibling `if` blocks each iterate `spotted` independently:

```lua
-- line 339 (rangedmax)
for fid, foe in pairs(spotted) do
    if core.fov.distance(...) <= range then uses[#uses+1] = ... end
end
-- line 346 (rangedtwotiles)  
for fid, foe in pairs(spotted) do
    if math.max(math.abs(...)) <= 2 then uses[#uses+1] = ... end
end
```

Each iterates the full `spotted` table. These could be merged into a single pass. More critically, a single talent can be inserted into `uses` multiple times if multiple distance conditions match (e.g., an enemy both in range and within 2 tiles). This means duplicated entries, and the ordering sort later wastes time on them.

**Fix:** Single pass over `spotted` with `elseif` chain, or restructure to set flags then iterate once.

---

## P5. O(n×m) name-based ordering lookup

**Lines 370-395** — When custom ordering is enabled, the code matches talents by **name string** instead of by key:

```lua
for index, talent in ipairs(game.player.talents_auto_order) do     -- N items
    -- resolve talent_name from key ...
    for i = table.getn(temp_uses), 1, -1 do                        -- M items
        if use.name == talent_name then
            table.insert(sorted_uses, use)
            table.remove(temp_uses, i)                              -- O(M) shift
        end
    end
end
```

- `table.remove` from a list table is O(n) — it shifts all subsequent elements.
- Combined with the nested loop, worst case is O(N × M × M). For 30 ordered talents and 20 usable ones: ~18000+ operations per tick.
- Name comparison is fragile (see functional bug — localization, fake talent tables).
- This also defeats the optimization of doing `spotHostiles` once (P1), since the ordering happens after the main loop and can't skip talents early.

**Fix:** Store talents in `uses` keyed by `tid` (a table `uses_by_id`), then iterate `talents_auto_order` directly to build `sorted_uses` via hash lookup in O(N+M) total.

---

## P6. Empty dead loops

**Lines 425-427, 429-434** — Two `for` loops with no work:

```lua
for _, use in ipairs(uses) do          -- line 425
    --game.log("Triggered:"..use.name) -- commented out
end
for _, use in ipairs(uses) do          -- line 429
    --game.log("Used:"..use.name)      -- commented out
    --game.log(use.tid)
    if use.is_item then
        --game.log("inventory item")   -- commented out
    end
```

These iterate `uses` table twice with all branches dead. Adds unnecessary iteration.

**Fix:** Remove both loops.

---

## P7. HP thresholds recomputed per talent via division

**Lines 222, 227, 232, 237, 289** — HP% thresholds use division:

```lua
(self.life < (self.max_life / 1.2))     -- 80% threshold
(self.life > (self.max_life / 1.2))
(self.life < (self.max_life / 1.65))    -- 60% threshold
```

These are inside the per-talent loop. `max_life / 1.2` and `max_life / 1.65` produce the same value every iteration. With 20 talents, that's ~120 divisions per tick.

Negligible relative to FOV passes, but an easy fix.

**Fix:** Lift to constants before the loop.

---

## Impact Summary

| Bug | Overhead | Frequency | Impact |
|-----|----------|-----------|--------|
| P1: `spotHostiles` per talent | ~314 tiles × N iterations | Every tick | **High** — scales with talents |
| P2: effect/rank loops per talent | O(effects + foes) × N | Every tick | Medium |
| P3: second `calc_circle` | ~314 tiles per tick | Every tick with modes 50/150 | Medium (but it's already broken, so zero effect currently) |
| P4: redundant spotted scans | 3× iteration of foes per talent | Every tick with range talents | Medium |
| P5: O(n×m×m) name ordering | 30×20×20 worst case | Every tick when ordering enabled | Medium-High |
| P6: dead loops | 2× iteration of uses | Every tick | Trivial |
| P7: repeated division | 6 divs × N talents | Every tick | Trivial |

**Primary fix:** Lift `spotHostiles()` and effect/rank loops before the talent loop. This alone eliminates ~95% of the excess work.
