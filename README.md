# Alea (Godot)

Godot 4 port of **Alea**. Web prototype: **`../Alea`**

## Run

1. Install [Godot 4.3+](https://godotengine.org/download)
2. Open this folder as the project
3. Press **F5**

## Features

See [docs/PORT_STATUS.md](docs/PORT_STATUS.md) for parity with the React prototype.

## Layout

| Path | Role |
|------|------|
| `data/` | JSON rules (gyms, powers, limits) |
| `scripts/core/` | Grid, patterns, run session, gym/safari/tournament rules |
| `scripts/autoload/` | GameData, SaveService, GameState, SceneNav |
| `scenes/` | Menu, game, tournament, settings |

## Steam (later)

`export_presets.cfg` includes a Windows desktop stub. Add GodotSteam when shipping.
