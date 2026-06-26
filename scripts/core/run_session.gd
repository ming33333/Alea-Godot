class_name RunSession
extends RefCounted

signal state_changed
signal dice_rerolled(row: int, col: int, new_value: int)
signal dice_swished(from_row: int, from_col: int, to_row: int, to_col: int)
signal rows_locked(completions: Array)
signal power_rewarded(power_type: String, source_row: int, previous_charge: int, is_new_unlock: bool)
signal show_modal(modal: String)
signal hide_modal(modal: String)

enum Modal {
	NONE, ROUND_COMPLETE, LEVEL_UP, NUMBER_PICKER, GAME_VICTORY,
	GAME_OVER, TOURNAMENT_WIN, SWAP_POWER, STUCK, RESTART_CONFIRM
}

var challenge_orb_id: String = "vanilla"
var is_tournament: bool = false
var tournament_opponent_id: String = ""
var tournament_loadout: Array = []
var tournament_stolen: String = ""
var tournament_on_match_win: Callable = Callable()

var level: int = 1
var hearts: int = 3
var switches_used: int = 0
var rerolls_used: int = 0
var grid: Array = []
var awarded_rows: Dictionary = {}
var power_earned_rows: Dictionary = {}
var unlocked_powers: Dictionary = {}
var power_charges: Dictionary = {}
var charges_at_level_start: Dictionary = {}
var active_power_type: String = ""
var active_target_row: int = -1
var active_target_col: int = -1
var selected_row: int = -1
var selected_col: int = -1
var level_power_goal: String = ""
var level_up_pool: Array = []
var pending_swap_in: String = ""
var skip_choose_earn_rows: Dictionary = {}
var endless_mode: bool = false
var safari_countdown: int = 0
var blurred_cell_key: String = ""
var game_over: bool = false
var current_modal: int = Modal.NONE
var victory_badge_is_new: bool = false
var menu_orb_celebration_pending: bool = false
var max_owned_powers: int = 3
var fail_heart_processed: bool = false
var straight_switch_cap_bonus: int = 0
var combo_reroll_used: bool = false
var pending_row_swap_before: Array = []
var pending_swap_before_from: DiceCellData
var pending_swap_before_to: DiceCellData

var _safari_timer: SceneTreeTimer = null


func start_challenge_orb_run(challenge_orb: String) -> void:
	challenge_orb_id = challenge_orb
	is_tournament = false
	tournament_opponent_id = ""
	max_owned_powers = GameData.max_owned_powers_for_challenge_orb(challenge_orb_id)
	_reset_meta()
	_start_level(1, true)


func start_tournament_match(
	opponent_id: String,
	loadout: Array,
	stolen: String,
	on_win: Callable
) -> void:
	challenge_orb_id = "vanilla"
	is_tournament = true
	tournament_opponent_id = opponent_id
	tournament_loadout = loadout.duplicate()
	tournament_stolen = stolen
	tournament_on_match_win = on_win
	max_owned_powers = 3
	_reset_meta()
	unlocked_powers = TournamentRules.build_unlocked(loadout, stolen)
	level = int(GameData.level_limits.get("championship_level", 8))
	_init_tournament_charges()
	_start_level(level, false)


func _reset_meta() -> void:
	hearts = int(GameData.level_limits.get("max_hearts", 3))
	game_over = false
	endless_mode = false
	unlocked_powers = {}
	power_earned_rows = {}
	power_charges = _empty_charges()
	level_power_goal = ""
	fail_heart_processed = false
	straight_switch_cap_bonus = 0
	victory_badge_is_new = false
	menu_orb_celebration_pending = false


func _empty_charges() -> Dictionary:
	var d: Dictionary = {}
	for p in GameData.powers:
		d[str(p.get("type", ""))] = 0
	return d


func _start_level(lvl: int, new_run: bool) -> void:
	level = lvl
	switches_used = 0
	rerolls_used = 0
	selected_row = -1
	selected_col = -1
	_clear_power_activation()
	skip_choose_earn_rows = {}
	combo_reroll_used = false
	safari_countdown = 0
	blurred_cell_key = ""
	current_modal = Modal.NONE
	awarded_rows = {}
	power_earned_rows = {}
	for r in ChallengeOrbRules.initial_awarded_rows(challenge_orb_id):
		awarded_rows[r] = true
	var has_sc: bool = unlocked_powers.has("secondChances")
	var lucky: bool = is_tournament and tournament_opponent_id == "luckySeven"
	grid = ChallengeOrbRules.build_grid(challenge_orb_id, has_sc, lucky)
	if new_run:
		charges_at_level_start = _snapshot_charges()
	elif not is_tournament:
		_apply_charges_for_new_level()
		charges_at_level_start = _snapshot_charges()
	process_row_completions(false)
	_emit()


func _init_tournament_charges() -> void:
	power_charges = _empty_charges()
	for t in unlocked_powers:
		if PowerLogic.is_pattern_power(t) or t == "switchRows":
			power_charges[t] = maxi(power_charges.get(t, 0), 1)
	_apply_charges_for_new_level()
	charges_at_level_start = _snapshot_charges()


func _apply_charges_for_new_level() -> void:
	for p in GameData.powers:
		var t: String = str(p.get("type", ""))
		if PowerLogic.is_permanent(t):
			continue
		if PowerLogic.is_per_level(t) and unlocked_powers.has(t):
			power_charges[t] = 1
		elif PowerLogic.is_pattern_power(t):
			power_charges[t] = 0


func _snapshot_charges() -> Dictionary:
	return power_charges.duplicate()


func get_limits() -> Dictionary:
	var lim: Dictionary = LevelLimits.get_level_limits(level)
	lim.max_switches = PowerLogic.max_switches_for_level(
		level, unlocked_powers, straight_switch_cap_bonus
	)
	return lim


func switches_left() -> int:
	return PowerLogic.switches_remaining(
		level, switches_used, unlocked_powers, straight_switch_cap_bonus
	)


func rerolls_left() -> int:
	return LevelLimits.rerolls_remaining(level, rerolls_used)


func check_win() -> bool:
	var patterns: Array = _board_patterns()
	var opp: String = tournament_opponent_id if is_tournament else ""
	return TournamentRules.check_win_patterns(patterns, opp)


func _board_patterns() -> Array:
	var patterns: Array = []
	for row in grid:
		var vals: Array = []
		for c in row:
			vals.append(c.value)
		patterns.append(PatternCheck.check_pattern(vals))
	return patterns


func blocks_play() -> bool:
	if game_over or safari_countdown > 0:
		return true
	return (
		current_modal != Modal.NONE
		and current_modal != Modal.NUMBER_PICKER
	)


func can_offer_restart() -> bool:
	if game_over or is_tournament or check_win() or safari_countdown > 0:
		return false
	if (
		current_modal != Modal.NONE
		and current_modal != Modal.RESTART_CONFIRM
	):
		return false
	return hearts > 0


func request_restart_confirm() -> void:
	if not can_offer_restart():
		return
	current_modal = Modal.RESTART_CONFIRM
	_emit()


func cancel_restart_confirm() -> void:
	if current_modal == Modal.RESTART_CONFIRM:
		current_modal = Modal.NONE
		_emit()


func confirm_restart_level() -> void:
	if current_modal != Modal.RESTART_CONFIRM:
		return
	current_modal = Modal.NONE
	restart_level_voluntary()


func is_level_failed() -> bool:
	if check_win() or game_over or blocks_play():
		return false
	return PowerLogic.is_level_stuck(
		grid, level, switches_used, rerolls_used,
		unlocked_powers, active_power_type, power_charges, awarded_rows,
		straight_switch_cap_bonus
	)


func process_row_completions(emit_lock_fx: bool = true) -> void:
	var skip_rows: Dictionary = skip_choose_earn_rows.duplicate()
	skip_choose_earn_rows = {}
	var rows_done: Array = []
	var patterns: Array = []
	for row in grid:
		var vals: Array = []
		for c in row:
			vals.append(c.value)
		patterns.append(PatternCheck.check_pattern(vals))
	var pattern_counts: Dictionary = {}
	if is_tournament and tournament_opponent_id == "noThreeRepeats":
		for p in patterns:
			if p != PatternCheck.INCOMPLETE:
				pattern_counts[p] = pattern_counts.get(p, 0) + 1
	for row_index in range(patterns.size()):
		var pattern: String = str(patterns[row_index])
		var complete: bool = false
		if is_tournament:
			complete = TournamentRules.row_complete_for_opponent(
				pattern, tournament_opponent_id
			)
			if tournament_opponent_id == "noThreeRepeats" and pattern != PatternCheck.INCOMPLETE:
				complete = complete and pattern_counts.get(pattern, 0) <= 2
		else:
			complete = pattern != PatternCheck.INCOMPLETE
		if complete and not awarded_rows.has(row_index):
			rows_done.append({"index": row_index, "pattern": pattern})
	if rows_done.is_empty():
		_maybe_fail_level()
		return
	var newly_locked: Array = []
	for item in rows_done:
		var row_item: Dictionary = item
		var idx: int = int(row_item["index"])
		var pat: String = str(row_item["pattern"])
		awarded_rows[idx] = true
		newly_locked.append(idx)
		var row_charges: Dictionary = {}
		_add_pattern_charges_for_row(idx, pat, skip_rows, row_charges)
		for t in row_charges:
			var prev_charge: int = power_charges.get(t, 0)
			power_rewarded.emit(t, idx, prev_charge, false)
			power_charges[t] = prev_charge + int(row_charges[t])
		grid[idx] = _lock_row(grid[idx])
	if not newly_locked.is_empty() and emit_lock_fx:
		rows_locked.emit(rows_done)
	_apply_passive_completion_rewards(rows_done)
	_maybe_trigger_combo_reroll()
	_check_win_flow()


func _add_pattern_charges_for_row(
	row_index: int,
	pattern: String,
	skip_choose_rows: Dictionary,
	charges_add: Dictionary
) -> void:
	for t in unlocked_powers:
		if not PowerLogic.is_pattern_power(t):
			continue
		var key: String = PowerLogic.power_earn_key(row_index, t)
		if power_earned_rows.has(key):
			continue
		if not PowerLogic.row_earns_goal(t, pattern):
			continue
		if (
			t == "chooseNumber"
			and pattern == PatternCheck.FIVE_KIND
			and skip_choose_rows.has(row_index)
		):
			power_earned_rows[key] = true
			continue
		power_earned_rows[key] = true
		charges_add[t] = charges_add.get(t, 0) + 1


func _award_pattern_charges_on_completed_rows() -> void:
	var charges_add: Dictionary = {}
	for row_index in awarded_rows:
		var vals: Array = []
		for c in grid[row_index]:
			vals.append(c.value)
		var pattern: String = PatternCheck.check_pattern(vals)
		if pattern == PatternCheck.INCOMPLETE:
			continue
		_add_pattern_charges_for_row(row_index, pattern, {}, charges_add)
	for t in charges_add:
		power_charges[t] = power_charges.get(t, 0) + charges_add[t]


func _apply_passive_completion_rewards(rows_done: Array) -> void:
	if not unlocked_powers.has("straightSwitch"):
		return
	for item in rows_done:
		var row_item: Dictionary = item
		if str(row_item.get("pattern", "")) != PatternCheck.STRAIGHT:
			continue
		var row_index: int = int(row_item.get("index", -1))
		var key: String = PowerLogic.power_earn_key(row_index, "straightSwitch")
		if power_earned_rows.has(key):
			continue
		power_earned_rows[key] = true
		straight_switch_cap_bonus += 1
		_log_power(
			"straightSwitch +1 max switch cap row=%d max_switches=%d switches_left=%d"
			% [row_index, get_limits().max_switches, switches_left()]
		)


func _maybe_trigger_combo_reroll() -> void:
	if not unlocked_powers.has("comboReroll") or combo_reroll_used:
		return
	if not _board_has_completed_pattern(PatternCheck.FULL_HOUSE):
		return
	if not _board_has_completed_pattern(PatternCheck.STRAIGHT):
		return
	var left: int = rerolls_left()
	if left <= 0:
		return
	rerolls_used -= left
	combo_reroll_used = true
	_log_power(
		"comboReroll doubled rerolls remaining=%d rerolls_left=%d"
		% [left, rerolls_left()]
	)
	power_rewarded.emit("comboReroll", -1, left, false)


func _board_has_completed_pattern(pattern: String) -> bool:
	for row_index in awarded_rows:
		var vals: Array = []
		for c in grid[int(row_index)]:
			vals.append(c.value)
		if PatternCheck.check_pattern(vals) == pattern:
			return true
	return false


func _lock_row(row: Array) -> Array:
	var out: Array = []
	for cell in row:
		var c: DiceCellData = cell.duplicate_cell()
		c.locked = true
		out.append(c)
	return out


func _check_win_flow() -> void:
	if not check_win():
		if (
			is_tournament
			and TournamentRules.mandate_failed(
				_board_patterns(), tournament_opponent_id
			)
		):
			game_over = true
			_clear_power_activation()
			current_modal = Modal.GAME_OVER
			_emit()
			return
		if is_level_failed():
			_handle_fail()
		_emit()
		return
	_clear_power_activation()
	if is_tournament:
		current_modal = Modal.TOURNAMENT_WIN
		_emit()
		return
	var max_lvl: int = int(GameData.level_limits.get("max_level", 8))
	if level >= max_lvl and not endless_mode:
		if not is_tournament:
			victory_badge_is_new = SaveService.award_challenge_orb_badge(challenge_orb_id)
			if victory_badge_is_new:
				menu_orb_celebration_pending = true
		current_modal = Modal.GAME_VICTORY
		_emit()
		return
	level_up_pool = _pick_level_up_pool()
	current_modal = Modal.ROUND_COMPLETE
	_emit()


func _pick_level_up_pool() -> Array:
	var available: Array = []
	for p in GameData.powers:
		var t: String = str(p.get("type", ""))
		if not unlocked_powers.has(t):
			available.append(t)
	available.shuffle()
	var n: int = int(GameData.level_limits.get("level_up_offer_count", 2))
	return available.slice(0, mini(n, available.size()))


func _handle_fail() -> void:
	if fail_heart_processed:
		return
	fail_heart_processed = true
	_clear_power_activation()
	if is_tournament:
		game_over = true
		current_modal = Modal.GAME_OVER
		return
	hearts -= 1
	if hearts <= 0:
		game_over = true
		current_modal = Modal.GAME_OVER
	else:
		current_modal = Modal.STUCK


func retry_level() -> void:
	fail_heart_processed = false
	current_modal = Modal.NONE
	_restore_charges_snapshot()
	_start_level(level, false)


func restart_level_voluntary() -> void:
	if game_over or check_win() or is_tournament:
		return
	if hearts <= 1:
		hearts = 0
		game_over = true
		current_modal = Modal.GAME_OVER
		_emit()
		return
	hearts -= 1
	retry_level()


func select_die(row: int, col: int) -> void:
	if blocks_play() or current_modal == Modal.GAME_VICTORY:
		if active_power_type != "" or current_modal != Modal.NONE:
			_log_power(
				"select_die blocked (%d,%d) %s"
				% [row, col, _power_block_reason(blocks_play(), current_modal)]
			)
		return
	if active_power_type in ["switchRows", "chooseNumber", "setAnyNumber"]:
		_log_power(
			"select_die -> power click (%d,%d) active=%s %s"
			% [row, col, active_power_type, _power_context()]
		)
		_handle_power_click(row, col)
		return
	if is_level_failed() and not check_win():
		return
	var cell: DiceCellData = grid[row][col]
	if cell.locked:
		return
	if selected_row < 0:
		selected_row = row
		selected_col = col
	elif selected_row == row and selected_col == col:
		selected_row = -1
		selected_col = -1
	elif _try_switch(row, col):
		pass
	else:
		selected_row = row
		selected_col = col
	_emit()


func reroll_die(row: int, col: int) -> void:
	if blocks_play():
		return
	if is_level_failed() and not check_win():
		return
	var cell: DiceCellData = grid[row][col]
	if cell.locked or cell.no_reroll:
		return
	if rerolls_left() <= 0:
		return
	var new_val: int = ChallengeOrbRules.reroll_value(cell.value, challenge_orb_id)
	cell.push_history(new_val)
	rerolls_used += 1
	dice_rerolled.emit(row, col, new_val)
	var pending: Dictionary = {"row": row, "col": col, "value": new_val}
	if GameData.is_countdown_challenge_orb(challenge_orb_id) and rerolls_used % int(
		GameData.level_limits.get("safari_reroll_interval", 3)
	) == 0:
		_trigger_safari(pending)
	else:
		_after_reroll_side_effects(pending)
	process_row_completions()


func _after_reroll_side_effects(pending: Dictionary) -> void:
	if is_tournament and tournament_opponent_id == "rerollChaos":
		_apply_random_die_change()
	if is_tournament and tournament_opponent_id == "blurPerReroll":
		blurred_cell_key = _pick_random_unlocked_key()
	_emit()


func _trigger_safari(pending: Dictionary) -> void:
	safari_countdown = 3
	# UI will tick countdown; on complete call finish_safari_wave
	_pending_safari = pending
	_emit()


var _pending_safari: Dictionary = {}


func tick_safari_countdown() -> void:
	if safari_countdown <= 0:
		return
	safari_countdown -= 1
	if safari_countdown <= 0:
		grid = SafariRules.apply_wave(grid, challenge_orb_id, _pending_safari)
		_after_reroll_side_effects(_pending_safari)
		process_row_completions()
	_emit()


func _apply_random_die_change() -> void:
	var pick: Dictionary = _pick_random_unlocked_pos()
	if pick.is_empty():
		return
	var v: int = ChallengeOrbRules.roll_die()
	grid[int(pick["row"])][int(pick["col"])].push_history(v)


func _pick_random_unlocked_key() -> String:
	var p: Dictionary = _pick_random_unlocked_pos()
	if p.is_empty():
		return ""
	return "%d:%d" % [int(p["row"]), int(p["col"])]


func _pick_random_unlocked_pos() -> Dictionary:
	var cands: Array = []
	for r in range(grid.size()):
		for c in range(grid[r].size()):
			var cell: DiceCellData = grid[r][c]
			if not cell.locked and not cell.no_reroll:
				cands.append({"row": r, "col": c})
	if cands.is_empty():
		return {}
	return cands[randi() % cands.size()] as Dictionary


func _try_switch(row: int, col: int) -> bool:
	if switches_left() <= 0:
		return false
	if grid[row][col].locked or grid[selected_row][selected_col].locked:
		return false
	var sw_any: bool = active_power_type == "switchAnywhere"
	var side: bool = unlocked_powers.has("switchHorizontal")
	var vjump: bool = unlocked_powers.has("verticalJump")
	var sc: bool = unlocked_powers.has("secondChances")
	var adj_v: bool = selected_col == col and abs(selected_row - row) == 1
	var adj_h: bool = selected_row == row and abs(selected_col - col) == 1
	var v_jump: bool = vjump and selected_col == col and PowerLogic.can_vertical_jump(
		grid, selected_row, row, col
	)
	var valid: bool = adj_v or sw_any or (side and adj_h) or v_jump
	if not valid:
		return false
	var free_side: bool = side and adj_h
	var normal_v: bool = adj_v and not sw_any and not free_side
	_swap_values(selected_row, selected_col, row, col)
	if normal_v and sc:
		_apply_second_chances(selected_row, row, col)
	elif not free_side:
		grid[selected_row][selected_col].locked = true
		grid[row][col].locked = true
	switches_used += 1
	if free_side:
		selected_row = row
		selected_col = col
	else:
		selected_row = -1
		selected_col = -1
	if sw_any:
		power_charges["switchAnywhere"] = power_charges.get("switchAnywhere", 0) - 1
		active_power_type = ""
	process_row_completions()
	return true


func _swap_values(r1: int, c1: int, r2: int, c2: int) -> void:
	pending_swap_before_from = grid[r1][c1].duplicate_cell()
	pending_swap_before_to = grid[r2][c2].duplicate_cell()
	var t: int = grid[r1][c1].value
	grid[r1][c1].value = grid[r2][c2].value
	grid[r2][c2].value = t
	dice_swished.emit(r1, c1, r2, c2)


func _apply_second_chances(r1: int, r2: int, col: int) -> void:
	for r in [r1, r2]:
		var cell: DiceCellData = grid[r][col]
		var rem: int = cell.vertical_swaps_remaining
		if rem < 0:
			rem = int(GameData.level_limits.get("second_chances_vertical_swaps", 2))
		rem -= 1
		cell.vertical_swaps_remaining = rem
		if rem <= 0:
			cell.locked = true


func activate_power(power_type: String) -> void:
	if not unlocked_powers.has(power_type):
		_log_power("activate rejected: not unlocked type=%s" % power_type)
		return
	var prev: String = active_power_type
	active_power_type = power_type
	active_target_row = -1
	active_target_col = -1
	selected_row = -1
	selected_col = -1
	_log_power(
		"activate %s (was %s) charges=%s rerolls_left=%d %s"
		% [
			power_type,
			prev if not prev.is_empty() else "(none)",
			power_charges.get(power_type, 0),
			rerolls_left(),
			_power_context(),
		]
	)
	_emit()


func _clear_power_activation() -> void:
	active_power_type = ""
	active_target_row = -1
	active_target_col = -1
	selected_row = -1
	selected_col = -1


func clear_active_power() -> void:
	if (
		active_power_type == ""
		and active_target_row < 0
		and selected_row < 0
		and current_modal != Modal.NUMBER_PICKER
	):
		return
	_log_power("clear active was=%s target=(%d,%d) %s" % [
		active_power_type if not active_power_type.is_empty() else "(none)",
		active_target_row,
		active_target_col,
		_power_context(),
	])
	_clear_power_activation()
	if current_modal == Modal.NUMBER_PICKER:
		current_modal = Modal.NONE
	_emit()


func _handle_power_click(row: int, col: int) -> void:
	match active_power_type:
		"switchRows":
			_log_power("handle switchRows row=%d target_row=%d" % [row, active_target_row])
			_handle_switch_rows(row)
		"setAnyNumber", "chooseNumber":
			_log_power(
				"handle %s die=(%d,%d) locked=%s value=%d"
				% [
					active_power_type,
					row,
					col,
					grid[row][col].locked,
					grid[row][col].value,
				]
			)
			_handle_pattern_pick(row, col)
		_:
			_log_power("handle ignored active=%s die=(%d,%d)" % [active_power_type, row, col])


func _handle_switch_rows(row: int) -> void:
	if active_target_row < 0:
		_log_power("switchRows pick first row=%d" % row)
		active_target_row = row
		_emit()
		return
	if active_target_row == row:
		_log_power("switchRows cancelled same row=%d" % row)
		active_power_type = ""
		active_target_row = -1
		_emit()
		return
	_log_power("switchRows swap rows %d <-> %d" % [active_target_row, row])
	_swap_rows(active_target_row, row, true)
	power_charges["switchRows"] = power_charges.get("switchRows", 0) - 1
	active_power_type = ""
	active_target_row = -1
	process_row_completions()
	_emit()


func _swap_rows(first: int, second: int, emit_swish: bool = false) -> void:
	pending_row_swap_before.clear()
	for c in range(grid[0].size()):
		pending_row_swap_before.append({
			"from": grid[first][c].duplicate_cell(),
			"to": grid[second][c].duplicate_cell(),
		})
	for c in range(grid[0].size()):
		grid[first][c].swap_with(grid[second][c])
	_swap_row_meta(first, second)
	if emit_swish:
		dice_swished.emit(first, -1, second, -1)


func _swap_row_meta(row_a: int, row_b: int) -> void:
	var a_awarded: bool = awarded_rows.has(row_a)
	var b_awarded: bool = awarded_rows.has(row_b)
	if b_awarded:
		awarded_rows[row_a] = true
	else:
		awarded_rows.erase(row_a)
	if a_awarded:
		awarded_rows[row_b] = true
	else:
		awarded_rows.erase(row_b)
	for pt in PowerLogic.PATTERN_POWERS:
		var key_a: String = PowerLogic.power_earn_key(row_a, pt)
		var key_b: String = PowerLogic.power_earn_key(row_b, pt)
		var a_earned: bool = power_earned_rows.has(key_a)
		var b_earned: bool = power_earned_rows.has(key_b)
		if b_earned:
			power_earned_rows[key_a] = true
		else:
			power_earned_rows.erase(key_a)
		if a_earned:
			power_earned_rows[key_b] = true
		else:
			power_earned_rows.erase(key_b)
	var a_skip: bool = skip_choose_earn_rows.has(row_a)
	var b_skip: bool = skip_choose_earn_rows.has(row_b)
	if b_skip:
		skip_choose_earn_rows[row_a] = true
	else:
		skip_choose_earn_rows.erase(row_a)
	if a_skip:
		skip_choose_earn_rows[row_b] = true
	else:
		skip_choose_earn_rows.erase(row_b)


func _handle_pattern_pick(row: int, col: int) -> void:
	if active_power_type == "chooseNumber":
		if awarded_rows.has(row):
			_log_power("pattern pick rejected: row %d already awarded" % row)
			return
		var vals: Array = []
		for c in grid[row]:
			vals.append(c.value)
		var pattern: String = PatternCheck.check_pattern(vals)
		if pattern != PatternCheck.INCOMPLETE:
			_log_power(
				"pattern pick rejected: row %d already complete (%s)" % [row, pattern]
			)
			return
	if active_power_type == "setAnyNumber":
		if awarded_rows.has(row):
			_log_power("pattern pick rejected: row %d is locked" % row)
			return
		if grid[row][col].locked:
			_log_power("pattern pick rejected: die (%d,%d) is locked" % [row, col])
			return
	active_target_row = row
	active_target_col = col
	current_modal = Modal.NUMBER_PICKER
	_log_power(
		"number picker opened %s target=(%d,%d) cell_value=%d %s"
		% [
			active_power_type,
			row,
			col,
			grid[row][col].value,
			_power_context(),
		]
	)
	_emit()


func apply_number_pick(number: int) -> void:
	if active_power_type not in ["chooseNumber", "setAnyNumber"]:
		_log_power(
			"apply_number_pick ignored n=%d active=%s modal=%s"
			% [number, active_power_type, _modal_name()]
		)
		return
	var tr: int = active_target_row
	var tc: int = active_target_col
	var ptype: String = active_power_type
	var before: int = grid[tr][tc].value if ptype == "setAnyNumber" else -1
	if ptype == "setAnyNumber" and not PowerLogic.die_valid_for_set_any(
		grid, awarded_rows, tr, tc
	):
		_log_power(
			"apply_number_pick rejected setAnyNumber locked target=(%d,%d)" % [tr, tc]
		)
		return
	if ptype == "chooseNumber":
		skip_choose_earn_rows[tr] = true
		for c in range(grid[tr].size()):
			grid[tr][c].push_history(number)
	else:
		grid[tr][tc].push_history(number)
		rerolls_used += 1
	power_charges[ptype] = power_charges.get(ptype, 0) - 1
	active_power_type = ""
	active_target_row = -1
	active_target_col = -1
	current_modal = Modal.NONE
	if ptype == "setAnyNumber":
		_log_power(
			"setAnyNumber applied n=%d die=(%d,%d) %d->%d charges_left=%d rerolls_used=%d"
			% [
				number,
				tr,
				tc,
				before,
				grid[tr][tc].value,
				power_charges.get(ptype, 0),
				rerolls_used,
			]
		)
	else:
		_log_power(
			"chooseNumber applied n=%d row=%d charges_left=%d"
			% [number, tr, power_charges.get(ptype, 0)]
		)
	process_row_completions()
	_emit()


func reroll_trade() -> void:
	if not PowerLogic.can_trade_rerolls(
		level, switches_used, rerolls_used, unlocked_powers
	):
		return
	rerolls_used += 2
	switches_used -= 1
	_emit()


func effective_max_owned_powers() -> int:
	return PowerLogic.effective_max_owned_powers(max_owned_powers, unlocked_powers)


func choose_level_up_power(power_type: String) -> void:
	if unlocked_powers.has(power_type):
		return
	if unlocked_powers.size() < effective_max_owned_powers():
		_apply_level_up(power_type)
		return
	pending_swap_in = power_type
	current_modal = Modal.SWAP_POWER
	_emit()


func swap_out_power(replaced: String) -> void:
	if pending_swap_in == "":
		return
	var gained: String = pending_swap_in
	unlocked_powers.erase(replaced)
	unlocked_powers[gained] = true
	if active_power_type == replaced:
		active_power_type = ""
	if PowerLogic.is_pattern_power(gained):
		level_power_goal = gained
	pending_swap_in = ""
	current_modal = Modal.NONE
	power_rewarded.emit(gained, -1, 0, true)
	level += 1
	_start_level(level, false)


func cancel_swap_power() -> void:
	if pending_swap_in == "" or current_modal != Modal.SWAP_POWER:
		return
	pending_swap_in = ""
	current_modal = Modal.LEVEL_UP
	_emit()


func _apply_level_up(power_type: String) -> void:
	unlocked_powers[power_type] = true
	if PowerLogic.is_pattern_power(power_type):
		level_power_goal = power_type
	power_rewarded.emit(power_type, -1, 0, true)
	level += 1
	_start_level(level, false)


func keep_current_powers_at_level_up() -> void:
	if current_modal != Modal.LEVEL_UP:
		return
	pending_swap_in = ""
	level += 1
	_start_level(level, false)


func continue_after_round() -> void:
	if is_tournament:
		_dev_advance_championship_level()
		return
	if level_up_pool.is_empty():
		level += 1
		_start_level(level, false)
		return
	current_modal = Modal.LEVEL_UP
	_emit()


func start_endless() -> void:
	endless_mode = true
	current_modal = Modal.NONE
	level = int(GameData.level_limits.get("max_level", 8)) + 1
	_start_level(level, false)


func _restore_charges_snapshot() -> void:
	for t in power_charges:
		if PowerLogic.is_permanent(t):
			continue
		power_charges[t] = charges_at_level_start.get(t, 0)


func tournament_match_won() -> void:
	current_modal = Modal.NONE
	if tournament_on_match_win.is_valid():
		tournament_on_match_win.call()


func dev_complete_level() -> void:
	if game_over:
		return
	if is_tournament:
		_dev_advance_championship_level()
		return
	if check_win():
		return
	if current_modal == Modal.ROUND_COMPLETE:
		return
	var patterns: Array = [
		[1, 1, 1, 1, 1],
		[1, 1, 1, 2, 2],
		[1, 2, 3, 4, 5],
		[6, 6, 6, 6, 6],
		[2, 3, 4, 5, 6],
	]
	grid = []
	awarded_rows = {}
	for row_vals in patterns:
		var row: Array = []
		for v in row_vals:
			var cell := DiceCellData.new(v, true)
			row.append(cell)
		grid.append(row)
		awarded_rows[grid.size() - 1] = true
	selected_row = -1
	selected_col = -1
	active_power_type = ""
	level_up_pool = _pick_level_up_pool()
	current_modal = Modal.ROUND_COMPLETE
	_emit()


func _dev_advance_championship_level() -> void:
	if current_modal == Modal.SWAP_POWER:
		return
	if current_modal == Modal.LEVEL_UP:
		return
	pending_swap_in = ""
	selected_row = -1
	selected_col = -1
	active_power_type = ""
	if current_modal == Modal.ROUND_COMPLETE and not level_up_pool.is_empty():
		current_modal = Modal.LEVEL_UP
		_emit()
		return
	level_up_pool = _pick_level_up_pool()
	if level_up_pool.is_empty():
		level += 1
		_start_level(level, false)
		return
	current_modal = Modal.LEVEL_UP
	_emit()


func dev_complete_championship_battle() -> void:
	if game_over or not is_tournament:
		return
	pending_swap_in = ""
	selected_row = -1
	selected_col = -1
	active_power_type = ""
	active_target_row = -1
	active_target_col = -1
	current_modal = Modal.NONE
	tournament_match_won()


func dev_add_heart() -> void:
	if game_over:
		return
	var max_h: int = int(GameData.level_limits.get("max_hearts", 3))
	hearts = mini(hearts + 1, max_h)
	_emit()


func dev_refill_resources() -> void:
	switches_used = 0
	rerolls_used = 0
	_emit()


func dev_grant_power(power_type: String) -> String:
	if game_over:
		return "Game over - start a new run"
	if power_type.is_empty():
		return "Pick a power"
	if unlocked_powers.has(power_type):
		var owned: Dictionary = GameData.get_power_def(power_type)
		return "Already owned: %s" % str(owned.get("label", power_type))
	if unlocked_powers.size() >= effective_max_owned_powers():
		return "Loadout full (%d/%d) - drop one first" % [
			unlocked_powers.size(), effective_max_owned_powers()
		]
	unlocked_powers[power_type] = true
	power_rewarded.emit(power_type, -1, 0, true)
	if PowerLogic.is_per_level(power_type):
		power_charges[power_type] = maxi(power_charges.get(power_type, 0), 1)
	elif PowerLogic.is_pattern_power(power_type):
		power_charges[power_type] = 0
		if level_power_goal.is_empty():
			level_power_goal = power_type
	_award_pattern_charges_on_completed_rows()
	if pending_swap_in == power_type:
		pending_swap_in = ""
		if current_modal == Modal.SWAP_POWER:
			current_modal = Modal.NONE
	_emit()
	var def: Dictionary = GameData.get_power_def(power_type)
	return "Added %s (%d/%d)" % [
		str(def.get("label", power_type)),
		unlocked_powers.size(),
		effective_max_owned_powers(),
	]


func dev_remove_power(power_type: String) -> String:
	if game_over:
		return "Game over - start a new run"
	if power_type.is_empty():
		return "Pick a power"
	if not unlocked_powers.has(power_type):
		var def: Dictionary = GameData.get_power_def(power_type)
		return "Not in loadout: %s" % str(def.get("label", power_type))
	unlocked_powers.erase(power_type)
	power_charges[power_type] = 0
	if active_power_type == power_type:
		active_power_type = ""
		active_target_row = -1
		active_target_col = -1
		selected_row = -1
		selected_col = -1
	if level_power_goal == power_type:
		level_power_goal = ""
	if pending_swap_in == power_type:
		pending_swap_in = ""
		if current_modal == Modal.SWAP_POWER:
			current_modal = Modal.NONE
	_emit()
	var removed: Dictionary = GameData.get_power_def(power_type)
	return "Removed %s (%d/%d)" % [
		str(removed.get("label", power_type)),
		unlocked_powers.size(),
		effective_max_owned_powers(),
	]


func _maybe_fail_level() -> void:
	if game_over or current_modal != Modal.NONE:
		return
	if is_level_failed():
		_handle_fail()


func _emit() -> void:
	_maybe_fail_level()
	state_changed.emit()


func _log_power(message: String) -> void:
	DebugLog.alea_log("Power", message)


func _modal_name(modal_id: int = -1) -> String:
	var m: int = current_modal if modal_id < 0 else modal_id
	match m:
		Modal.NONE:
			return "NONE"
		Modal.ROUND_COMPLETE:
			return "ROUND_COMPLETE"
		Modal.LEVEL_UP:
			return "LEVEL_UP"
		Modal.NUMBER_PICKER:
			return "NUMBER_PICKER"
		Modal.GAME_VICTORY:
			return "GAME_VICTORY"
		Modal.GAME_OVER:
			return "GAME_OVER"
		Modal.TOURNAMENT_WIN:
			return "TOURNAMENT_WIN"
		Modal.SWAP_POWER:
			return "SWAP_POWER"
		Modal.STUCK:
			return "STUCK"
		Modal.RESTART_CONFIRM:
			return "RESTART_CONFIRM"
		_:
			return str(m)


func _power_context() -> String:
	return (
		"modal=%s target=(%d,%d) selected=(%d,%d) charges=%s rerolls=%d/%d"
		% [
			_modal_name(),
			active_target_row,
			active_target_col,
			selected_row,
			selected_col,
			power_charges,
			rerolls_left(),
			get_limits().get("max_rerolls", 0),
		]
	)


func _power_block_reason(blocked: bool, modal: int) -> String:
	var parts: PackedStringArray = []
	if game_over:
		parts.append("game_over")
	if safari_countdown > 0:
		parts.append("safari=%d" % safari_countdown)
	if modal == Modal.GAME_VICTORY:
		parts.append("victory_modal")
	if blocked and modal != Modal.NONE:
		parts.append("modal=%s" % _modal_name(modal))
	if active_power_type != "":
		parts.append("active=%s" % active_power_type)
	parts.append(_power_context())
	return " | ".join(parts)
