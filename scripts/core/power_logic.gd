class_name PowerLogic
extends RefCounted

const PATTERN_POWERS: Array[String] = [
	"chooseNumber", "switchAnywhere", "setAnyNumber"
]
const PERMANENT: Array[String] = [
	"switchHorizontal", "verticalJump", "secondChances", "rerollTrade",
	"extraSwitches", "straightSwitch", "comboReroll", "extraLoadout",
]
const EXTRA_SWITCHES_BONUS := 5
const LOADOUT_BONUS_AMOUNT := 2


static func is_pattern_power(t: String) -> bool:
	return t in PATTERN_POWERS


static func is_permanent(t: String) -> bool:
	return t in PERMANENT


static func is_per_level(t: String) -> bool:
	return t == "switchRows"


static func format_power_detail(def: Dictionary) -> String:
	var charge: String = str(def.get("charge_summary", "")).strip_edges()
	if charge.is_empty():
		charge = _fallback_charge_summary(str(def.get("type", "")))
	var desc: String = str(def.get("description", "")).strip_edges()
	if charge.is_empty():
		return desc
	if desc.is_empty():
		return charge
	return "%s\n\n%s" % [charge, desc]


static func format_power_short(def: Dictionary) -> String:
	var charge: String = str(def.get("charge_summary", "")).strip_edges()
	if charge.is_empty():
		charge = _fallback_charge_summary(str(def.get("type", "")))
	var dot: int = charge.find(".")
	if dot > 0:
		return charge.substr(0, dot + 1)
	return charge


static func _fallback_charge_summary(power_type: String) -> String:
	if is_pattern_power(power_type):
		var pattern: String = str(GameData.pattern_map.get(power_type, ""))
		return (
			"Charges: +1 each time you complete a %s row (x on the die). "
			% pattern
			+ "Resets to 0 at the start of each level."
		)
	if is_per_level(power_type):
		return (
			"1 charge per level - refreshes when the level starts (x on the die). "
			+ "Unused charges don't carry over."
		)
	if power_type == "rerollTrade":
		return "Always available - no charges. Costs 2 rerolls per use."
	if power_type == "extraSwitches":
		return "Always on while owned - adds +5 switches each level."
	if power_type == "straightSwitch":
		return "Always on while owned - +1 to your switch cap permanently each time you complete a Straight row (kept for the run)."
	if power_type == "comboReroll":
		return "Always on while owned - doubles remaining rerolls once per level when you have both a Full House and a Straight."
	if power_type == "extraLoadout":
		return "Always on while owned - +2 power slots in your loadout (this die uses one slot)."
	if is_permanent(power_type):
		return "Always on while owned - no charges."
	return ""


static func power_earn_key(row: int, power_type: String) -> String:
	return "%d:%s" % [row, power_type]


static func row_earns_goal(goal: String, pattern: String) -> bool:
	if pattern == PatternCheck.INCOMPLETE or is_permanent(goal):
		return false
	var mapped: String = str(GameData.pattern_map.get(goal, ""))
	return pattern == mapped


static func loadout_bonus(unlocked: Dictionary) -> int:
	return LOADOUT_BONUS_AMOUNT if unlocked.has("extraLoadout") else 0


static func effective_max_owned_powers(base_max: int, unlocked: Dictionary) -> int:
	return base_max + loadout_bonus(unlocked)


static func extra_switch_bonus(unlocked: Dictionary) -> int:
	return EXTRA_SWITCHES_BONUS if unlocked.has("extraSwitches") else 0


static func max_switches_for_level(
	level: int, unlocked: Dictionary, straight_cap_bonus: int = 0
) -> int:
	return (
		LevelLimits.get_level_limits(level).max_switches
		+ extra_switch_bonus(unlocked)
		+ straight_cap_bonus
	)


static func switches_remaining(
	level: int, switches_used: int, unlocked: Dictionary, straight_cap_bonus: int = 0
) -> int:
	return max_switches_for_level(level, unlocked, straight_cap_bonus) - switches_used


static func can_vertical_jump(
	grid: Array, from_row: int, to_row: int, col: int
) -> bool:
	if from_row == to_row:
		return false
	var a: DiceCellData = grid[from_row][col]
	var b: DiceCellData = grid[to_row][col]
	if a.locked or b.locked:
		return false
	var min_r: int = mini(from_row, to_row)
	var max_r: int = maxi(from_row, to_row)
	if max_r - min_r < 2:
		return false
	for r in range(min_r + 1, max_r):
		if not grid[r][col].locked:
			return false
	return true


static func has_usable_reroll(grid: Array, level: int, rerolls_used: int) -> bool:
	if LevelLimits.rerolls_remaining(level, rerolls_used) <= 0:
		return false
	for row in grid:
		for cell in row:
			if cell is DiceCellData and not cell.locked and not cell.no_reroll:
				return true
	return false


static func has_usable_switch(
	grid: Array,
	level: int,
	switches_used: int,
	unlocked: Dictionary,
	switch_anywhere_active: bool,
	switch_anywhere_charges: int,
	straight_cap_bonus: int = 0
) -> bool:
	if PowerLogic.switches_remaining(
		level, switches_used, unlocked, straight_cap_bonus
	) <= 0:
		return false
	var unlocked_cells: Array = []
	for r in range(grid.size()):
		for c in range(grid[r].size()):
			if not grid[r][c].locked:
				unlocked_cells.append({"row": r, "col": c})
	if unlocked_cells.size() < 2:
		return false
	if switch_anywhere_active or (
		unlocked.has("switchAnywhere") and switch_anywhere_charges > 0
	):
		return true
	var side: bool = unlocked.has("switchHorizontal")
	var vjump: bool = unlocked.has("verticalJump")
	for i in range(unlocked_cells.size()):
		for j in range(i + 1, unlocked_cells.size()):
			var a: Dictionary = unlocked_cells[i]
			var b: Dictionary = unlocked_cells[j]
			if a.col == b.col and abs(a.row - b.row) == 1:
				return true
			if side and a.row == b.row and abs(a.col - b.col) == 1:
				return true
			if vjump and a.col == b.col and can_vertical_jump(
				grid, a.row, b.row, a.col
			):
				return true
	return false


static func has_usable_choose_number(
	grid: Array,
	awarded_rows: Dictionary,
	unlocked: Dictionary,
	charges: Dictionary,
	active_type: String
) -> bool:
	if active_type == "chooseNumber":
		return true
	if not unlocked.has("chooseNumber"):
		return false
	if charges.get("chooseNumber", 0) <= 0:
		return false
	for r in range(grid.size()):
		if awarded_rows.has(r):
			continue
		var vals: Array = []
		for c in grid[r]:
			vals.append(c.value)
		if PatternCheck.check_pattern(vals) == PatternCheck.INCOMPLETE:
			return true
	return false


static func has_set_any_target(grid: Array, awarded_rows: Dictionary) -> bool:
	for r in range(grid.size()):
		if awarded_rows.has(r):
			continue
		for cell in grid[r]:
			if cell is DiceCellData and not cell.locked:
				return true
	return false


static func die_valid_for_set_any(
	grid: Array, awarded_rows: Dictionary, row: int, col: int
) -> bool:
	if awarded_rows.has(row):
		return false
	if row < 0 or row >= grid.size():
		return false
	if col < 0 or col >= grid[row].size():
		return false
	var cell: DiceCellData = grid[row][col]
	return not cell.locked


static func has_usable_set_any(
	grid: Array,
	awarded_rows: Dictionary,
	level: int,
	rerolls_used: int,
	unlocked: Dictionary,
	charges: Dictionary,
	active_type: String
) -> bool:
	if LevelLimits.rerolls_remaining(level, rerolls_used) <= 0:
		return false
	if active_type == "setAnyNumber":
		return has_set_any_target(grid, awarded_rows)
	if not unlocked.has("setAnyNumber"):
		return false
	if charges.get("setAnyNumber", 0) <= 0:
		return false
	return has_set_any_target(grid, awarded_rows)


static func has_usable_switch_rows(
	grid: Array,
	unlocked: Dictionary,
	charges: Dictionary,
	active_type: String
) -> bool:
	if active_type == "switchRows":
		return true
	if not unlocked.has("switchRows"):
		return false
	if charges.get("switchRows", 0) <= 0:
		return false
	return grid.size() >= 2


static func can_trade_rerolls(
	level: int,
	switches_used: int,
	rerolls_used: int,
	unlocked: Dictionary
) -> bool:
	return (
		unlocked.has("rerollTrade")
		and LevelLimits.rerolls_remaining(level, rerolls_used) >= 2
	)


static func is_level_stuck(
	grid: Array,
	level: int,
	switches_used: int,
	rerolls_used: int,
	unlocked: Dictionary,
	active_type: String,
	charges: Dictionary,
	awarded_rows: Dictionary,
	straight_cap_bonus: int = 0
) -> bool:
	var sw_ch: int = charges.get("switchAnywhere", 0)
	return (
		not has_usable_reroll(grid, level, rerolls_used)
		and not has_usable_switch(
			grid, level, switches_used, unlocked,
			active_type == "switchAnywhere", sw_ch, straight_cap_bonus
		)
		and not has_usable_set_any(
			grid, awarded_rows, level, rerolls_used, unlocked, charges, active_type
		)
		and not has_usable_switch_rows(
			grid, unlocked, charges, active_type
		)
		and not can_trade_rerolls(level, switches_used, rerolls_used, unlocked)
		and not has_usable_choose_number(
			grid, awarded_rows, unlocked, charges, active_type
		)
	)
