# Auto Use Tweaks — Architecture

## Overview

Replaces ToME's preset-mode auto-use system with composable per-talent rules.
No presets. No save migration (new addon, new games only).
Player-defined rules persist across characters via `config.settings`.

## Module Layout

```
overload/mod/auto_use/
  config.lua    — Schema, defaults, player/global state merge
  evaluate.lua  — Per-tick context + rule evaluation
  prefs.lua     — Cross-character preference persistence
  summary.lua   — Human-readable rule descriptions
```

## Data Flow

```
Right-click talent → UseTalents menu
  → Enable (defaults)
  → Configure (AutoUseOptions dialog → writes Config + Prefs)
  → Disable

Each tick:
  Player:automaticTalents()
    → Evaluate.buildContext(self) → ctx (spotted, HP, effects, click)
    → for each enabled talent:
        → Config.get(player, tid) → merged rule
        → Evaluate.evaluate(self, cfg, ctx, talent, range)
        → if pass: queue for use
    → sort by cooldown/energy
    → execute
```

## Rule Schema

See `docs/config-schema.md`.

## Persistence

| Scope | Storage | When |
|-------|---------|------|
| Per-character active rules | `game.player.talents_auto_config[tid]` | In-memory, saved to character file |
| Cross-character defaults | `config.settings.tome.auto_use_tweaks.talent_prefs[tid]` | `game:saveSettings()` on every change |

`Config.set()` writes to both. `Config.get()` merges: player config > global prefs > hard defaults.

## Key Design Decisions

- `talents_auto[tid]` = boolean enabled flag (vanilla-compatible)
- No mode integers (1–156) — all conditions defined declaratively
- "When safe" = no visible enemies + not blind + not `in_combat`
- Global prefs keyed by talent ID (e.g. `"T_SHOOT"`)
