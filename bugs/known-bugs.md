# Auto Use Tweaks — Known Bugs

File structure reference:

| File | Role |
|------|------|
| `hooks/load.lua` | Keybind definitions + toggle handlers |
| `superload/mod/class/Player.lua` | `automaticTalents()` — main auto-use logic |
| `superload/mod/class/Game.lua` | `mouseLeftClick` override |
| `superload/mod/class/Actor.lua` | `checkSetTalentAuto` — validation/prompts on set |
| `superload/mod/dialogs/UseTalents.lua` | Right-click menu for auto-use mode selection |
| `overload/mod/dialogs/AutoUserOrderListDialog.lua` | Talent ordering dialog |
| `overload/mod/dialogs/AutoUseOptions.lua` | Per-talent option dialog (unused) |
| `overload/data/keybinds/toggle-autotarget.lua` | Extra F1 keybind for auto-target |

---

## Critical

### 1. `proj` variable scoping — unreachable code

**File:** `superload/mod/class/Player.lua:270,280`

**Context:** The "can attack this turn" condition (auto-use modes 50/150) tries to detect projectiles between player and enemies. It calls `core.fov.calc_circle` with a callback, intent being to check for blocking projectiles.

**Bug:** `local proj = game.level.map(x, y, game.level.map.PROJECTILE)` is declared inside the anonymous callback function passed to `calc_circle`. The `proj` name shadows in the local scope of the callback only. On line 280, `if proj then` checks a *different* `proj` — a global variable that is never assigned, always nil.

```lua
-- line 270-273
core.fov.calc_circle(self.x, self.y, ..., function(_, x, y) return ... end, function(_, x, y)
    local proj = game.level.map(x, y, game.level.map.PROJECTILE)  -- LOCAL to this callback
end, nil)
-- ...
-- line 280
if proj then  -- GLOBAL proj, always nil
```

**Fix:** Lift `proj` to outer scope as a mutable capture, or set a flag in the outer scope from within the callback (e.g. `found_proj = true` in outer scope, set inside callback).

---

### 2. `PAI_STATE_FIGHT` and `ai_state` undefined

**File:** `superload/mod/class/Player.lua:284`

**Context:** The "can attack this turn" modes (50/150) try to check if the player is in combat mode.

**Bug:** Neither `PAI_STATE_FIGHT` nor `ai_state` exist anywhere in the T-Engine or ToME codebase. Both evaluate to `nil`. The condition `ai_state == PAI_STATE_FIGHT` is always false.

```lua
if ai_state == PAI_STATE_FIGHT and closingrange == 1 then
    auto_use = 1
```

```lua
local closingrange  -- also a global, never declared local
```

**Fix:** Either use the game's combat flag mechanism (`self.in_combat` exists in the engine) or remove this dead branch. Also declare `closingrange` local.

**Note:** The `closingrange` variable on line 277 is also a global without `local` declaration. Same for `proj`.

---

### 3. Toggle state stored on wrong object

**File:** `hooks/load.lua:33-54`

**Context:** Three keybinds toggle `talents_auto_off` and `talents_auto_ordering_off`. The `ToME:runDone` hook passes `self` = the **game** singleton. The toggle closures capture this `self` (game).

But `Player:automaticTalents()` (Player.lua:100,366) reads these flags on `self` where `self` = the **player** instance (`game.player`). These are different objects. The toggles set flags on `game.*` but the checks read from `game.player.*`.

```lua
-- hooks/load.lua (self = game)
TOGGLE_AUTO_USE = function()
    if self.talents_auto_off then       -- reads/writes game.talents_auto_off
        self.talents_auto_off = false
    else
        self.talents_auto_off = true

-- Player.lua:100 (self = player)
function _M:automaticTalents()
    if self.no_automatic_talents or self.talents_auto_off then return end  -- reads player.talents_auto_off
```

Same for `TOGGLE_AUTO_USE_ORDER` vs `Player.lua:366` (`game.player.talents_auto_ordering_off`).

**Fix:** Change toggles in `hooks/load.lua` to use `game.player` instead of `self`:

```lua
TOGGLE_AUTO_USE = function()
    if game.player.talents_auto_off then
        game.player.talents_auto_off = false
    else
        game.player.talents_auto_off = true
```

---

## High

### 4. Nil dereference on `o.use_power`

**File:** `superload/mod/dialogs/UseTalents.lua:174`

**Context:** When right-clicking a talent, the code tries to resolve inventory items. If `findInAllInventories` returns nil (item not found), `o` is nil.

```lua
local o = game.player:findInAllInventories(item.talent, ...)
if o and o.use_talent and o.use_talent.id then
    -- safe: o checked first
    ...
elseif o.use_power then  -- CRASH if o is nil
```

The first branch correctly guards with `o and`, but the `elseif` does not. If `o` is nil, Lua errors: `attempt to index a nil value (local 'o')`.

**Fix:** `elseif o and o.use_power then`

---

### 5. `False` typo instead of `false`

**File:** `overload/mod/dialogs/AutoUserOrderListDialog.lua:40`

```lua
if game.player.talents_auto_ordering_off == nil then
    game.player.talents_auto_ordering_off = False  -- should be false
end
```

Lua is case-sensitive. `False` is not a built-in value; it resolves to `nil` (global not found). The assignment does nothing — the field stays `nil` instead of being set to `false`. Downstream code that checks `if not game.player.talents_auto_ordering_off` still works because `nil` is falsy, but explicit `false` is the intended default.

**Fix:** Change `False` → `false`.

---

## Medium

### 6. `custom_talent_options` written but never read

**File:** `overload/mod/dialogs/AutoUseOptions.lua`

**Context:** The `AutoUseOptions` dialog lets the user configure per-talent options (available, enemy visible, distance range). These are saved to `game.player.custom_talent_options[tid]`.

**Bug:** `Player:automaticTalents()` never reads `game.player.custom_talent_options`. The configured options have zero effect on auto-use behavior. The entire dialog is decorative.

**Relevant sections:**
- Write: `AutoUseOptions.lua:44-58` (init sets defaults), `:99-145` (toggles update the table)
- Read: nowhere

**Fix:** Either integrate `custom_talent_options` into the `automaticTalents()` condition checks, or remove the dialog.

---

### 7. Fake talent table for `use_power` items

**File:** `superload/mod/class/Player.lua:124-130`

**Context:** Items with `use_power` (not `use_talent`) can't be resolved to a real talent definition. The code constructs a minimal stub table:

```lua
t = {name=tid, mode="activated", auto_use_check=false, no_energy=false}
```

**Bug:** This stub is passed to `preUseTalent()` on line 327 and other talent-checking functions. `preUseTalent` expects fields like `id`, resource costs, `is_spell`, `is_nature`, `no_breath`, `require`, etc. Missing fields cause:
- `preUseTalent` may return incorrect results or error on nil-index lookups
- Resource cost checks are skipped even if the power item has costs
- Sustained-mode checks may behave unpredictably
- Range calculations use a fallback `range = 1` even if the power has longer range

**Fix:** Either parse the `use_power` table for available metadata (range, etc.), or skip power-based items from auto-use entirely.

---

### 8. Menu items 101-103 have handlers but no menu entries

**File:** `superload/mod/dialogs/UseTalents.lua:443-448`

**Context:** The right-click menu (lines 196-301) builds a list of auto-use mode options with `what` values like `auto-en-57`, `auto-en-104` through `auto-en-156`. The `Dialog:listPopup` callback handles these with `elseif b.what == "auto-en-10X"` chains.

**Bug:** Handlers exist for `auto-en-101`, `auto-en-102`, `auto-en-103` but no corresponding menu item ever generates these values. Dead code that can never be reached.

```lua
-- line 443-448: handlers present
elseif b.what == "auto-en-101" then ...
elseif b.what == "auto-en-102" then ...
elseif b.what == "auto-en-103" then ...

-- but menu (lines 196-301) jumps from 57 straight to 104
```

**Fix:** Either add menu entries for 101-103 or remove the dead handlers.

---

## Low

### 9. Global variable pollution

**Files:** `superload/mod/class/Player.lua`, `superload/mod/class/Game.lua`

Several variables are used as globals without `local` declaration:

| Variable | File | Used For |
|----------|------|----------|
| `left_click_trigger` | Player.lua:7 | Signals auto-use that a left-click happened this tick |
| `lc_target` | Player.lua:8 | Stores the clicked actor as forced target |
| `talents_ran_check` | Player.lua:13 | Return value signaling that talents were used |
| `closingrange` | Player.lua:277 | Temp var in "can attack" check |
| `proj` | Player.lua:270 (no declaration) | Projectile detection flag (also scope-bugged, see #1) |

**Risk:** If another addon uses the same global names, behavior becomes undefined.

**Fix:** Add `local` declarations. For `left_click_trigger`, `lc_target`, and `talents_ran_check` which cross function boundaries, use a module-level local or store on the player instance.

---

### 10. `table.copy` overwrites global `table` library

**File:** `overload/mod/dialogs/AutoUserOrderListDialog.lua:223-226`

```lua
function table.copy(t)
    local u = { }
    for k, v in pairs(t) do u[k] = v end
    return setmetatable(u, getmetatable(t))
end
```

This adds a `copy` function to the global `table` library. Other code that depends on `table.copy` (if it exists) or that expects `table.copy` to be absent may break. Rarely an issue, but risky if this addon is used alongside others.

**Fix:** Rename to local function `local table_copy = ...` or rename as module method.

---

### 11. Typo: "Not and Item"

**File:** `superload/mod/dialogs/UseTalents.lua:158`

```lua
game.log("Not and Item")  -- should be "Not an Item"
```

Minor log message typo.

---

### 12. `mouseLeftClick` replaces original without fallback

**File:** `superload/mod/class/Game.lua:7-21`

The original `_M.mouseLeftClick` is saved as `mlc` on line 7 but never called. The addon completely replaces left-click behavior — no fallback to the standard `auto_shoot_talent` targeting if the addon's conditions aren't met.

The original `mouseLeftClick` (`tome/class/Game.lua:2710`) checked `auto_shoot_talent` and used that talent on the clicked hostile target. The addon's version instead triggers `player:act()` which runs `automaticTalents()`. If no auto-use talents trigger, no action is taken.

**Fix:** Add `local mlc = _M.mouseLeftClick` at the top, and call `mlc(self, mx, my)` as a fallback if the addon's conditions don't apply.
