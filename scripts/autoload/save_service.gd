extends Node

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
	return gym_id in get_earned_badges()


func has_all_menu_badges() -> bool:
	for g in GameData.menu_gym_modes:
		if not has_badge(g.id):
			return false
	return true


func award_gym_badge(gym_id: String) -> bool:
	var enabled := false
	for g in GameData.menu_gym_modes:
		if str(g.get("id", "")) == gym_id:
			enabled = true
			break
	if not enabled:
		return false
	if has_badge(gym_id):
		return false
	var ids: Array = []
	for b in get_earned_badges():
		ids.append(b)
	ids.append(gym_id)
	_write(BADGES_KEY, JSON.stringify(ids))
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


func _write(key: String, text: String) -> void:
	var f := FileAccess.open("user://%s.dat" % key, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
