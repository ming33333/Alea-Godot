class_name ChallengeOrbRules
extends RefCounted

const MIDDLE_ROW: int = 2
const HEAD_START: Array = [1, 2, 3, 4, 5]


static func roll_die() -> int:
	return randi_range(1, 6)


static func reroll_value(current: int, challenge_orb_id: String) -> int:
	if challenge_orb_id == "orderedReroll":
		var n: int = clampi(current, 1, 6)
		return 1 if n >= 6 else n + 1
	return roll_die()


static func initial_awarded_rows(challenge_orb_id: String) -> Array[int]:
	if challenge_orb_id == "middleStraight":
		return [MIDDLE_ROW]
	return []


static func build_grid(
	challenge_orb_id: String,
	has_second_chances: bool,
	place_lucky_seven: bool = false
) -> Array:
	var size: int = int(GameData.level_limits.get("grid_size", 5))
	var grid: Array = []
	for row_index in range(size):
		var row: Array = []
		for col_index in range(size):
			var cell := DiceCellData.new()
			if challenge_orb_id == "middleStraight" and row_index == MIDDLE_ROW:
				var v: int = HEAD_START[col_index]
				cell = DiceCellData.new(v, true)
			else:
				cell = DiceCellData.new(roll_die(), false)
			if has_second_chances:
				cell.vertical_swaps_remaining = int(
					GameData.level_limits.get("second_chances_vertical_swaps", 2)
				)
			row.append(cell)
		grid.append(row)
	if place_lucky_seven:
		grid = TournamentRules.place_lucky_seven(grid)
	return grid
