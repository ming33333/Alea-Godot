extends Node

signal badges_changed

const BADGES_KEY := "gym_badges"
const CHAMPION_KEY := "dice_champion"
const LAYOUT_KEY := "gym_menu_layout"


func _ready() -> void:
	DebugLog.log("SaveService", "_ready")


func get_earned_badges() -> Array[String]:
	var raw: String = _read(BADGES_KEY)
	if raw.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Array:
		return []
	var out: Array[String] = []
	var valid: Dictionary = {}
	for g in GameData.menu_gym_modes:
		valid[str(g.get("id", ""))] = true
	for id in parsed:
		if valid.has(str(id)):
			out.append(str(id))
	return out


func has_badge(gym_id: String) -> bool:
	var gid: String = str(gym_id)
	for b in get_earned_badges():
		if b == gid:
			return true
	return false


func has_all_menu_badges() -> bool:
	for g in GameData.menu_gym_modes:
		if not has_badge(str(g.get("id", ""))):
			return false
	return true


func _is_valid_menu_gym(gym_id: String) -> bool:
	for g in GameData.menu_gym_modes:
		if str(g.get("id", "")) == gym_id:
			return true
	return false


func force_award_badge(gym_id: String) -> bool:
	var gid: String = str(gym_id)
	if not _is_valid_menu_gym(gid):
		DebugLog.log_error("SaveService", "force_award_badge: invalid gym '%s'" % gid)
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


func award_gym_badge(gym_id: String) -> bool:
	var gid: String = str(gym_id)
	if not _is_valid_menu_gym(gid):
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


func award_dice_champion() -> void:
	_write(CHAMPION_KEY, "1")


func get_menu_layout() -> Dictionary:
	var raw: String = _read(LAYOUT_KEY)
	if raw.is_empty():
		return GameData.gym_menu_layout.duplicate()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var merged: Dictionary = GameData.gym_menu_layout.duplicate()
		for k in parsed:
			merged[k] = parsed[k]
		return merged
	return GameData.gym_menu_layout.duplicate()


func save_orb_position(gym_id: String, x: float, y: float) -> void:
	var layout: Dictionary = get_menu_layout()
	layout[gym_id] = {"x": clampf(x, 5.0, 95.0), "y": clampf(y, 5.0, 95.0)}
	_write(LAYOUT_KEY, JSON.stringify(layout))


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
