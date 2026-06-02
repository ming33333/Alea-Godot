extends Node
## Autoload placeholder — level, hearts, resources, unlocked powers.
## Port fields from Alea web prototype (DiceGridGame.tsx) as you implement parity.

var level: int = 1
var hearts: int = 3
var switches: int = 0
var rerolls: int = 0

func reset_run() -> void:
	level = 1
	hearts = 3
	switches = 0
	rerolls = 0
