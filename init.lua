long_name = "Automatic Transmission"
short_name = "automatic_transmission"
for_module = "tome"
version = {1,7,6}
addon_version = {0,0,4}
weight = 100
author = { "Gleesus", "admin@gleesus.net" }
homepage = "https://github.com/MrAwesome/auto-use-tweaks-improved"
description = [[An overhaul of auto-use. Fine-grained control over when talents are used.

Per-talent rules (right-click a talent to Configure):
* Trigger: auto each turn or only on left-click
* Enemies: require hostiles, forbid (safe only), or ignore
* HP: fire when health is above/below a threshold
* Debuff: require specific detrimental effect type (physical/mental/magical/any)
* Elite filter: skip when any visible enemy is elite+
* Range: talent_max, not_adjacent, two_tiles, or melee
* Distance band: custom min/max to nearest enemy
* Resting: only while resting or only while not resting
* Sustained: turn on when safe or off when enemies appear

Default hotkeys:
* Toggle auto-accept-target ALT+F1
* Toggle auto-use on/off CTRL+P (or ALT+SHIFT+P for a separate additional disable)
* Change auto-use-custom-priority ALT+SHIFT+O
* Toggle auto-use-custom-priority ALT+SHIFT+X

Based originally on this addon:
https://te4.org/games/addons/tome/auto_use_tweaks

NOTE: this was heavily vibe-coded, so do not be surprised if your character turns into a pumpkin.
]]
tags = {'auto-use', 'tweaks', 'auto', 'talent', 'use', 'custom'}
overload = true
superload = true
hooks = true
data = true
