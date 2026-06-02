# Port status

Godot project mirrors the web prototype in [Alea](../Alea) incrementally.

## Implemented

- **Data**: `data/gym_modes.json`, `powers.json`, `level_limits.json`, `gym_menu_layout.json`, `tournament.json`
- **Core loop**: 5×5 grid, patterns, switches/rerolls, levels 1–8, hearts, stuck/fail, row completion
- **Powers**: all 8 types, level-up offers, 3-power cap (2 in Tight Loadout gym), swap-out
- **Gyms**: vanilla, Safari Snap/Surge, Tight Loadout, Head Start; Step Up disabled in menu
- **Menu**: river map, draggable golden orbs, badges, championship gate
- **Championship**: power pick, bracket preview, 3 random opponents, thief/lucky seven rules (subset)
- **Saves**: `user://` badges, champion flag, orb layout
- **Settings**: master volume; `export_presets.cfg` stub for Windows (Steam/GodotSteam later)

## Spec reference

- [DiceGridGame.tsx](../../Alea/src/app/components/DiceGridGame.tsx)

## Play

Open `Alea-godot` in Godot 4.3+ and press F5.
