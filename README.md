# Alea (Godot)

Godot 4 port of **Alea**. Web prototype: **`../Alea`**

## Run

1. Install [Godot 4.3+](https://godotengine.org/download)
2. Open this folder as the project
3. Press **F5**

## Audio

- **`assets/dice_roll_default.mp3`** — default dice reroll SFX (double-click a die in-game).
- **Settings → Dice roll sound** — choose Default, Roll 2 (`dice_roll_2.mp3`), or Roll 3 (`dice_roll3.mp3`).
- Master volume is saved in `user://settings.cfg` via the **AudioSettings** autoload.

## Main menu background

The main menu plays **`assets/textures/river.ogv`** (Ogg Theora — the format Godot supports for video).

## Dev cheats

Edit **`data/dev_cheats.json`** — add strings to `unlock_codes` (default: `alea`, `devmode`, `wrench`).

Unlock in **Settings** (cheat code field), or type a code on the **main menu** / **in-game**. In the editor, cheats are usually on when `always_on_in_editor` is true. In-game, use the **🔧** button for the dev menu (grant any power up to your loadout max, complete level, refill resources, etc.).

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
