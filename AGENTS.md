# Auto Use Tweaks — Agent Guide

## File structure reference

| File | Role |
|------|------|
| `overload/mod/auto_use/config.lua` | Rule schema, defaults, player/global merge |
| `overload/mod/auto_use/evaluate.lua` | Per-tick context builder + rule evaluator |
| `overload/mod/auto_use/prefs.lua` | Cross-character preference persistence |
| `overload/mod/auto_use/summary.lua` | Human-readable rule descriptions |
| `overload/mod/dialogs/AutoUseOptions.lua` | Rule-builder dialog (right-click Configure) |
| `overload/mod/dialogs/AutoUserOrderListDialog.lua` | Talent ordering + summary column |
| `superload/mod/class/Player.lua` | `automaticTalents()` — main loop + execution |
| `superload/mod/class/Actor.lua` | `checkSetTalentAuto()` — enable/disable with confirmation |
| `superload/mod/dialogs/UseTalents.lua` | Right-click menu (Enable/Disable/Configure) |
| `hooks/load.lua` | Keybinds + toggles (fixed: uses `game.player`) |
| `overload/data/settings.lua` | Initializes `config.settings.tome.auto_use_tweaks` |
| `docs/` | Architecture, schema, hacking guide |

## Architecture (3 sentences)

No presets. Each talent stores composable rules in `talents_auto_config[tid]`.
`evaluate.lua` builds a tick context once (spotted hostiles, HP, effects, click state)
then checks each enabled talent's rules. Cross-character defaults in `config.settings`.

## Key conventions

- `talents_auto[tid]` = boolean enabled flag only (vanilla-compatible `isTalentAuto`)
- `talents_auto_config[tid]` = full rule table (see `docs/config-schema.md` for fields)
- `evaluate()` returns `true/false` — caller handles `preUseTalent`, cooldowns, sustained toggles
- `AutoUseOptions:init(item)` takes `{name=tid, display_name=...}`, NOT `(player, tid)`
- "When safe" = no enemies visible + not blind + not `in_combat`
- No save migration — new addon for new games only
