# Alea (Godot)

Godot 4 port of **Alea**. Web prototype: **`../Alea`**

## About

**Alea** is a dice puzzle roguelite. You have a 5×5 board and a handful of rerolls and swaps each level. Your job is to shape every row into a valid pattern — straights, full houses, five of a kind, and more — then lock those dice in place. Complete all five rows to clear the level, earn a new power for your loadout, and push deeper into the run.

Powers are tied to the patterns you finish: land a straight to unlock free swaps anywhere, a full house for precise set-die control, five of a kind to rewrite a whole row. Each gym on the world map twists the rules — ordered rerolls, safari countdowns, tighter loadouts, head-start boards — and awards a badge when you reach level 8. Collect every badge to unlock the portal and take the **Dice Master Test**: three random games, win all three, and earn the title **Dice Master**.

## Run

1. Install [Godot 4.3+](https://godotengine.org/download)
2. Open this folder as the project
3. Press **F5**

## Audio

- **`assets/sfx/dice_roll_default.mp3`** — default dice reroll SFX (double-click a die in-game).
- **Settings → Dice roll sound** — choose Default, Roll 2 (`dice_roll_2.mp3`), or Roll 3 (`dice_roll3.mp3`).
- Master volume is saved in `user://settings.cfg` via the **AudioSettings** autoload.

## Main menu background

The main menu plays **`assets/textures/river.ogv`** (Ogg Theora — the format Godot supports for video).

## Dev cheats

Edit **`data/dev_cheats.json`** — add strings to `unlock_codes` (default: `alea`, `devmode`, `wrench`).

Unlock in **Settings** (cheat code field), or type a code on the **main menu** / **in-game**. In the editor, cheats are usually on when `always_on_in_editor` is true. In-game, use the wrench button for the dev menu (grant any power up to your loadout max, complete level, refill resources, etc.).

## Features

See [docs/PORT_STATUS.md](docs/PORT_STATUS.md) for parity with the React prototype.

## Layout

| Path | Role |
|------|------|
| `data/` | JSON rules (gyms, powers, limits) |
| `scripts/core/` | Grid, patterns, run session, gym/safari/tournament rules |
| `scripts/autoload/` | GameData, SaveService, GameState, SceneNav, DevCheats |
| `data/dev_cheats.json` | Cheat unlock codes |
| `scenes/` | Menu, game, tournament, settings |

## Steam (later)

`export_presets.cfg` includes a Windows desktop stub. Add GodotSteam when shipping.
