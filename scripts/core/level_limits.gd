class_name LevelLimits
extends RefCounted

static func get_level_limits(level: int) -> Dictionary:
	var base_sw: int = int(GameData.level_limits.get("base_switches", 5))
	var base_rr: int = int(GameData.level_limits.get("base_rerolls", 15))
	return {
		"max_switches": maxi(0, base_sw - int((level - 1) / 2)),
		"max_rerolls": maxi(0, base_rr - (level - 1)),
	}


static func switches_remaining(level: int, switches_used: int) -> int:
	return get_level_limits(level).max_switches - switches_used


static func rerolls_remaining(level: int, rerolls_used: int) -> int:
	return get_level_limits(level).max_rerolls - rerolls_used
