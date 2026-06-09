class_name TournamentRules
extends RefCounted

static func pick_opponents(count: int) -> Array[String]:
	var pool: Array[String] = []
	for o in GameData.tournament_opponents:
		var oid: String = str(o.get("id", ""))
		if not oid.is_empty():
			pool.append(oid)
	if pool.is_empty():
		push_error("TournamentRules: no opponents loaded from GameData")
		return []
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


static func pick_stolen_power(loadout: Array) -> String:
	if loadout.is_empty():
		return ""
	return loadout[randi() % loadout.size()]


static func build_unlocked(loadout: Array, stolen: String) -> Dictionary:
	var d: Dictionary = {}
	for p in loadout:
		if str(p) != stolen:
			d[str(p)] = true
	return d


static func place_lucky_seven(grid: Array) -> Array:
	var candidates: Array = []
	for r in range(grid.size()):
		for c in range(grid[r].size()):
			var cell: DiceCellData = grid[r][c]
			if not cell.locked:
				candidates.append(Vector2i(c, r))
	if candidates.is_empty():
		return grid
	var pick: Vector2i = candidates[randi() % candidates.size()]
	var new_grid: Array = []
	for r in range(grid.size()):
		var row: Array = []
		for c in range(grid[r].size()):
			var cell: DiceCellData = grid[r][c].duplicate_cell()
			if c == pick.x and r == pick.y:
				cell.value = 7
				cell.locked = true
				cell.no_reroll = true
				cell.push_history(7)
			row.append(cell)
		new_grid.append(row)
	return new_grid


static func row_complete_for_opponent(pattern: String, opponent_id: String) -> bool:
	if opponent_id == "straightSpecialist":
		return pattern == PatternCheck.STRAIGHT
	return pattern != PatternCheck.INCOMPLETE


static func check_win_patterns(patterns: Array, opponent_id: String) -> bool:
	if opponent_id == "noThreeRepeats":
		var counts: Dictionary = {}
		for p in patterns:
			if p == PatternCheck.INCOMPLETE:
				continue
			counts[p] = counts.get(p, 0) + 1
		if counts.values().any(func(n): return n >= 3):
			return false
		return patterns.all(func(p): return p != PatternCheck.INCOMPLETE)
	if opponent_id != "":
		return patterns.all(
			func(p): return row_complete_for_opponent(p, opponent_id)
		)
	return patterns.all(func(p): return p != PatternCheck.INCOMPLETE)
