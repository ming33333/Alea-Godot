# Alea (Godot)

Godot 4 port of **Alea**. The web prototype lives in the sibling folder:

**`../Alea`** — Vite + React (reference implementation / spec)

## Open in Godot

1. Install [Godot 4.3+](https://godotengine.org/download)
2. **Project → Import** or **Open** → select this folder (`Alea-godot`)
3. Run the project (F5) — main scene: `scenes/main_menu.tscn`

## Folder layout

| Path | Purpose |
|------|---------|
| `scenes/` | `.tscn` scenes (menu, game grid, modals) |
| `scripts/` | GDScript — split by role (see `docs/ARCHITECTURE.md`) |
| `scripts/autoload/` | Singletons (`GameState`, saves later) |
| `data/` | JSON / `.tres` for powers, gym modes, level limits |
| `assets/` | Art, audio (copy or symlink from `../Alea/public/` as needed) |

## Porting notes

- Gameplay spec: `../Alea/src/app/components/DiceGridGame.tsx`
- Gym modes: `../Alea/src/app/gymModes.ts`
- Badges / saves: `../Alea/src/app/gymBadges.ts`, `championship.ts`
- Migration plan: `../Alea/src/.cursor/plans/godot_steam_migration_82c0de2c.plan.md`

This is a **manual rewrite**, not an automatic export from React.

## Assets from the web prototype

Example (run from this folder):

```bash
cp ../Alea/public/river.jpg assets/textures/
```

Or symlink if you want the menu background to stay in sync during prototyping.

## Steam (later)

Target: Windows desktop first, then mobile / Switch per the migration plan. Add GodotSteam and export presets when you are ready to ship.
# Alea-Godot
