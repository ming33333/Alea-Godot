extends Node

signal badges_changed

const BADGES_KEY := "challenge_orb_badges"
const LEGACY_BADGES_KEY := "gym_badges"
const CHAMPION_KEY := "dice_champion"
const CHAMPION_CROWN_KEY := "dice_champion_crown"
const CROWNS_KEY := "dice_champion_crowns"
const LAYOUT_KEY := "challenge_orb_menu_layout"
const LEGACY_LAYOUT_KEY := "gym_menu_layout"
const BADGE_BOX_OPEN_KEY := "badge_box_open"
const WELCOME_SEEN_KEY := "welcome_seen"


func _ready() -> void:
	DebugLog.log("SaveService", "_ready")


func get_earned_badges() -> Array[String]:
	var raw: String = _read_with_legacy(BADGES_KEY, LEGACY_BADGES_KEY)
	if raw.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Array:
		return []
	var out: Array[String] = []
	var valid: Dictionary = {}
	for g in GameData.menu_challenge_orbs:
		valid[str(g.get("id", ""))] = true
	for id in parsed:
		if valid.has(str(id)):
			out.append(str(id))
	return out


func has_badge(challenge_orb_id: String) -> bool:
	var gid: String = str(challenge_orb_id)
	for b in get_earned_badges():
		if b == gid:
			return true
	return false


func has_all_menu_badges() -> bool:
	if GameData.menu_challenge_orbs.is_empty():
		return false
	for g in GameData.menu_challenge_orbs:
		if not has_badge(str(g.get("id", ""))):
			return false
	return true


func _is_valid_menu_challenge_orb(challenge_orb_id: String) -> bool:
	for g in GameData.menu_challenge_orbs:
		if str(g.get("id", "")) == challenge_orb_id:
			return true
	return false


func force_award_badge(challenge_orb_id: String) -> bool:
	var gid: String = str(challenge_orb_id)
	if not _is_valid_menu_challenge_orb(gid):
		DebugLog.log_error("SaveService", "force_award_badge: invalid challenge orb '%s'" % gid)
		return false
	if has_badge(gid):
		DebugLog.log("SaveService", "force_award_badge: already had '%s'" % gid)
		return true
	var ids: Array = []
	for b in get_earned_badges():
		ids.append(b)
	ids.append(gid)
	if not _write(BADGES_KEY, JSON.stringify(ids)):
		DebugLog.log_error("SaveService", "force_award_badge: write failed")
		return false
	badges_changed.emit()
	DebugLog.log("SaveService", "force_award_badge: awarded '%s'" % gid)
	return true


func force_award_all_badges() -> int:
	var earned_set: Dictionary = {}
	for badge_id in get_earned_badges():
		earned_set[badge_id] = true
	var ids: Array = []
	var added: int = 0
	for g in GameData.menu_challenge_orbs:
		var gid: String = str(g.get("id", ""))
		if gid.is_empty():
			continue
		if not earned_set.has(gid):
			added += 1
		ids.append(gid)
	if not _write(BADGES_KEY, JSON.stringify(ids)):
		DebugLog.log_error("SaveService", "force_award_all_badges: write failed")
		return -1
	badges_changed.emit()
	DebugLog.log("SaveService", "force_award_all_badges: added %d" % added)
	return added


func award_challenge_orb_badge(challenge_orb_id: String) -> bool:
	var gid: String = str(challenge_orb_id)
	if not _is_valid_menu_challenge_orb(gid):
		return false
	if has_badge(gid):
		return false
	var ids: Array = []
	for b in get_earned_badges():
		ids.append(b)
	ids.append(gid)
	if not _write(BADGES_KEY, JSON.stringify(ids)):
		return false
	badges_changed.emit()
	return true


func is_dice_champion() -> bool:
	return _read(CHAMPION_KEY) == "1"


func get_dice_champion_crown_index() -> int:
	if not is_dice_champion():
		return 1
	var raw: String = _read(CHAMPION_CROWN_KEY)
	if not raw.is_empty():
		return clampi(int(raw), 1, DiceCrownArt.crown_count())
	var crowns: Array[int] = get_earned_crowns()
	if crowns.is_empty():
		return 1
	return crowns[crowns.size() - 1]


func get_earned_crowns() -> Array[int]:
	if not is_dice_champion():
		return []
	var raw: String = _read(CROWNS_KEY)
	if not raw.is_empty():
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Array:
			var out: Array[int] = []
			var seen: Dictionary = {}
			for v in parsed:
				var idx: int = clampi(int(v), 1, DiceCrownArt.crown_count())
				if seen.has(idx):
					continue
				seen[idx] = true
				out.append(idx)
			out.sort()
			return out
	var legacy: String = _read(CHAMPION_CROWN_KEY)
	if not legacy.is_empty():
		return [clampi(int(legacy), 1, DiceCrownArt.crown_count())]
	return [1]


func has_crown(crown_index: int) -> bool:
	var idx: int = clampi(crown_index, 1, DiceCrownArt.crown_count())
	for c in get_earned_crowns():
		if c == idx:
			return true
	return false


func has_any_crown() -> bool:
	return is_dice_champion()


func has_all_crowns() -> bool:
	for crown_idx in range(1, DiceCrownArt.crown_count() + 1):
		if not has_crown(crown_idx):
			return false
	return is_dice_champion()


func has_unearned_crown() -> bool:
	if not is_dice_champion():
		return true
	for crown_idx in range(1, DiceCrownArt.crown_count() + 1):
		if not has_crown(crown_idx):
			return true
	return false


func award_dice_champion(crown_index: int = 1) -> void:
	var idx: int = clampi(crown_index, 1, DiceCrownArt.crown_count())
	var was_champion: bool = is_dice_champion()
	var crowns: Array[int] = []
	if was_champion:
		crowns = get_earned_crowns()
	var added: bool = not crowns.has(idx)
	if not was_champion:
		crowns.clear()
		crowns.append(idx)
	elif added:
		crowns.append(idx)
		crowns.sort()
	_write(CHAMPION_KEY, "1")
	_write(CROWNS_KEY, JSON.stringify(crowns))
	_write(CHAMPION_CROWN_KEY, str(idx))
	if added or not was_champion:
		badges_changed.emit()


func is_badge_box_open() -> bool:
	return _read(BADGE_BOX_OPEN_KEY) == "1"


func set_badge_box_open(open: bool) -> void:
	_write(BADGE_BOX_OPEN_KEY, "1" if open else "0")


func has_seen_welcome() -> bool:
	return _read(WELCOME_SEEN_KEY) == "1"


func mark_welcome_seen() -> void:
	_write(WELCOME_SEEN_KEY, "1")


func get_menu_layout() -> Dictionary:
	var raw: String = _read_with_legacy(LAYOUT_KEY, LEGACY_LAYOUT_KEY)
	if raw.is_empty():
		return GameData.challenge_orb_menu_layout.duplicate()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var merged: Dictionary = GameData.challenge_orb_menu_layout.duplicate()
		for k in parsed:
			merged[k] = parsed[k]
		return merged
	return GameData.challenge_orb_menu_layout.duplicate()


func save_orb_position(challenge_orb_id: String, x: float, y: float) -> void:
	var layout: Dictionary = get_menu_layout()
	layout[challenge_orb_id] = {"x": clampf(x, 5.0, 95.0), "y": clampf(y, 5.0, 95.0)}
	_write(LAYOUT_KEY, JSON.stringify(layout))


func reset_all_user_data() -> void:
	for key in [
		BADGES_KEY, LEGACY_BADGES_KEY, CHAMPION_KEY, CHAMPION_CROWN_KEY, CROWNS_KEY,
		LAYOUT_KEY, LEGACY_LAYOUT_KEY, BADGE_BOX_OPEN_KEY, WELCOME_SEEN_KEY
	]:
		_delete_user_file("%s.dat" % key)
	_delete_user_file("settings.cfg")
	_delete_user_file("dev_cheats_unlocked.dat")
	GameState.reset_tournament()
	GameState.show_champion_celebration = false
	DevCheats.reset_saved_state()
	AudioSettings.load_settings()
	DiceSprites.load_settings()
	badges_changed.emit()
	DebugLog.log("SaveService", "reset_all_user_data")


func _delete_user_file(relative_path: String) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(relative_path):
		dir.remove(relative_path)


func _read_with_legacy(key: String, legacy_key: String) -> String:
	var text: String = _read(key)
	if text.is_empty() and not legacy_key.is_empty():
		text = _read(legacy_key)
		if not text.is_empty():
			_write(key, text)
	return text


func _read(key: String) -> String:
	if not FileAccess.file_exists("user://%s.dat" % key):
		return ""
	var f := FileAccess.open("user://%s.dat" % key, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _write(key: String, text: String) -> bool:
	var path: String = "user://%s.dat" % key
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveService: could not write %s (err %s)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	return true
