class_name SafariRules
extends RefCounted

static func apply_pending_reroll(grid: Array, row: int, col: int, value: int) -> Array:
	var cell: DiceCellData = grid[row][col]
	if cell.locked:
		return grid
	var new_grid: Array = _clone_grid(grid)
	var target: DiceCellData = new_grid[row][col]
	target.push_history(value)
	return new_grid


static func apply_wave(grid: Array, challenge_orb_id: String, pending: Dictionary) -> Array:
	var g: Array = apply_pending_reroll(
		grid, int(pending["row"]), int(pending["col"]), int(pending["value"])
	)
	return apply_grid_change(g, challenge_orb_id)


static func apply_grid_change(grid: Array, challenge_orb_id: String) -> Array:
	if challenge_orb_id == "countdownOne":
		var pick: Dictionary = _pick_random_unlocked(grid)
		if pick.is_empty():
			return grid
		var new_grid: Array = _clone_grid(grid)
		var v: int = ChallengeOrbRules.roll_die()
		new_grid[int(pick["row"])][int(pick["col"])].push_history(v)
		return new_grid
	if challenge_orb_id == "countdownAll":
		var new_grid: Array = _clone_grid(grid)
		for r in range(new_grid.size()):
			for c in range(new_grid[r].size()):
				var cell: DiceCellData = new_grid[r][c]
				if not cell.locked:
					cell.push_history(ChallengeOrbRules.roll_die())
		return new_grid
	return grid


static func _pick_random_unlocked(grid: Array) -> Dictionary:
	var candidates: Array = []
	for r in range(grid.size()):
		for c in range(grid[r].size()):
			var cell: DiceCellData = grid[r][c]
			if not cell.locked:
				candidates.append({"row": r, "col": c})
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()] as Dictionary


static func _clone_grid(grid: Array) -> Array:
	var out: Array = []
	for row in grid:
		var r: Array = []
		for cell in row:
			r.append(cell.duplicate_cell())
		out.append(r)
	return out
