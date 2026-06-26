# Config Schema

Each talent has a rule table stored in `game.player.talents_auto_config[tid]`
(or cross-character in `config.settings.tome.auto_use_tweaks.talent_prefs[tid]`).

## Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch |
| `trigger` | `"auto"\|"left_click"` | `"auto"` | When to fire |
| `enemy_presence` | `nil\|"require"\|"forbid"` | `nil` | Enemy visibility requirement |
| `hp` | `nil\|{op, pct}` | `nil` | HP threshold (e.g. `{op="<", pct=80}`) |
| `hp_custom` | `nil\|{op, pct}` | `nil` | Custom HP override. Takes precedence over `hp` when set. Supports any 0-100 value. |
| `effects` | `nil\|"physical"\|"mental"\|"magical"\|"any"` | `nil` | Detrimental effect filter |
| `enemy_rank_max` | `nil\|number` | `nil` | Max enemy rank (2 = skip elites+) |
| `distance` | `nil\|{min, max}` | `nil` | Chebyshev distance band to any foe |
| `range` | `nil\|"talent_max"\|"not_adjacent"\|"two_tiles"\|"melee"` | `nil` | Range mode |
| `resting` | `nil\|true\|false` | `nil` | Resting state filter |
| `sustained` | `nil\|"on_when_safe"\|"off_when_enemies"` | `nil` | Sustained behavior |

## Semantics

- **`trigger = "left_click"`** — talent only fires when player left-clicked a hostile target this tick
- **`enemy_presence = "forbid"`** — requires no enemies visible, not blind, and not `in_combat`
- **`range = "not_adjacent"`** — enemy must be ≥2 tiles (chebyshev) AND within talent range
- **`distance`** — used alongside `range` for fine-grained chebyshev band
- **`sustained = "on_when_safe"`** — activates sustain when safe, won't sustain otherwise
- **`sustained = "off_when_enemies"`** — deactivates sustain when enemies appear

## Examples

```lua
-- "Shoot when enemies in range, not adjacent"
cfg = {
  trigger = "auto",
  enemy_presence = "require",
  range = "not_adjacent",
}

-- "Heal when HP < 60% and enemies visible"
cfg = {
  enemy_presence = "require",
  hp = {op = "<", pct = 60},
}

-- "Toggle shield on when entering town (safe)"
cfg = {
  sustained = "on_when_safe",
}
```

## Merging Rules

`Config.get()` merges in order:
1. Hard defaults (`overload/mod/auto_use/config.lua`)
2. Cross-character prefs (`config.settings`)
3. Current character config (`game.player.talents_auto_config`)

Higher-priority wins. `nil` fields cascade to the next level.
