# Alea Godot architecture

Mirror responsibilities from the React prototype — avoid one monolithic script.

| Module | Path (planned) | Responsibility |
|--------|----------------|----------------|
| `GameState` | `scripts/autoload/game_state.gd` | Level, hearts, switches, rerolls, unlocked powers, charges |
| `GridModel` | `scripts/game/grid_model.gd` | 5×5 cells, awarded rows, pattern checks |
| `PowerRegistry` | `data/powers.json` + loader | Power defs (earn pattern, charge rules) |
| `PowerExecutor` | `scripts/game/power_executor.gd` | Apply switch, reroll, make-5-kind, etc. |
| `RunController` | `scripts/game/run_controller.gd` | Win / fail / stuck, level-up, charge earn |
| `SaveService` | `scripts/services/save_service.gd` | `user://` saves; Steam Cloud later |
| Scenes | `scenes/` | `main_menu`, `game`, `die_cell`, modals |

## Input

Abstract input early: mouse → touch → gamepad (Switch).

## Resolution

Design at **1280×720** with Control anchors; scale for other aspect ratios.

## Reference

Spec source: `../../Alea/src/app/components/DiceGridGame.tsx`
