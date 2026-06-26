# Hacking Guide

## Adding a new rule condition

1. Add field to `_M.defaults` in `config.lua`
2. Add check in `evaluate.lua` `evaluate()` function
3. Add UI toggle in `AutoUseOptions:generateList()`
4. Add description mapping in `summary.lua` `describe()`

## The evaluation pipeline

```
Evaluate.buildContext(self, left_click, lc_target)
  → spotted[] (hostile actors in LOS)
  → physical/mental/magical (detrimental effect flags)
  → max_rank (highest enemy rank)
  → left_click (boolean)
  → lc_target

Evaluate.evaluate(self, cfg, ctx, talent, talent_range)
  → true/false (can this talent fire?)
  → handles sustained toggle logic internally
```

### Context is computed once per tick in `Player:automaticTalents()`.
Rules loop over the cached context — no redundant FOV calls.

## Order of evaluation

1. `enabled` flag
2. `trigger` (auto vs left-click)
3. `resting` state
4. `enemy_presence` (require/forbid)
5. `hp` threshold
6. `effects` filter
7. `enemy_rank_max` filter
8. `sustained` mode (return early for sustain toggles)
9. `range` + `distance` checks against each spotted foe

## Cross-character prefs

`prefs.lua` serializes to a `game:saveSettings()` chunk.
Format is Lua code written to the settings file:

```lua
tome.auto_use_tweaks.talent_prefs = {
  ["T_SHOOT"] = { trigger = "auto", enemy_presence = "require", range = "not_adjacent" },
}
```

To reset a talent's global pref: `Prefs.set(tid, nil)`.
To reset all: clear `config.settings.tome.auto_use_tweaks.talent_prefs`.

## Key modules reference

| File | Purpose |
|------|---------|
| `auto_use/config.lua` | Schema, `get()`, `set()`, `enable()`, `disable()` |
| `auto_use/evaluate.lua` | `buildContext()`, `evaluate()`, `isSafe()` |
| `auto_use/prefs.lua` | `get()`, `set()`, `save()` (cross-char) |
| `auto_use/summary.lua` | `describe(cfg)` → human string |
| `dialogs/AutoUseOptions.lua` | Rule builder dialog |
| `dialogs/AutoUserOrderListDialog.lua` | Ordering + rule summary column |

## Common pitfalls

- `AutoUseOptions:init()` receives `item` with `{name=tid, display_name=...}` — NOT `(player, tid)`
- `talents_auto[tid]` is boolean `true` when enabled — do NOT store mode numbers there
- `evaluate()` does NOT call `preUseTalent` or check cooldowns — the caller (`Player:automaticTalents()`) handles those
- Item talents (`use_power`) create a fake `t = {name=tid, mode="activated", ...}` with no real talent def
