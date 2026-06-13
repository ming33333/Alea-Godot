extends Node
## Loads JSON game data from res://data/

var gym_modes: Array = []
var menu_gym_modes: Array = []
var powers: Array = []
var pattern_map: Dictionary = {}
var level_limits: Dictionary = {}
var gym_menu_layout: Dictionary = {}
var tournament_opponents: Array = []
var tournament_pickable: Array = []
var gym_config: Dictionary = {}
var _badge_texture_cache: Dictionary = {}

const GYM_MODES_PATH := "res://data/gym_modes.json"
const POWERS_PATH := "res://data/powers.json"
const LEVEL_LIMITS_PATH := "res://data/level_limits.json"
const LAYOUT_PATH := "res://data/gym_menu_layout.json"
const TOURNAMENT_PATH := "res://data/tournament.json"

const GYM_ORB_COLORS: Dictionary = {
	"vanilla": Color(0.52, 0.68, 0.54, 0.9),
	"orderedReroll": Color(0.55, 0.62, 0.78, 0.9),
	"countdownOne": Color(0.85, 0.68, 0.42, 0.9),
	"countdownAll": Color(0.50, 0.66, 0.72, 0.9),
	"twoSlots": Color(0.65, 0.55, 0.72, 0.9),
	"middleStraight": Color(0.80, 0.52, 0.44, 0.9),
}
const GYM_ORB_FALLBACK_COLOR := Color(0.62, 0.60, 0.58, 0.9)
const GYM_BACKGROUND_LIGHTEN := 0.28


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var gyms_doc: Variant = _parse_json_file(GYM_MODES_PATH)
	if gyms_doc is Dictionary:
		gym_config = gyms_doc
		gym_modes = gyms_doc.get("gyms", [])
		menu_gym_modes = []
		for g in gym_modes:
			if g.get("enabled", true):
				menu_gym_modes.append(g)

	var powers_doc: Variant = _parse_json_file(POWERS_PATH)
	if powers_doc is Dictionary:
		powers = powers_doc.get("powers", [])
		pattern_map = powers_doc.get("pattern_map", {})
		tournament_pickable = powers_doc.get("tournament_pickable", [])

	level_limits = _parse_json_file(LEVEL_LIMITS_PATH)
	if not level_limits is Dictionary:
		level_limits = {}

	gym_menu_layout = _parse_json_file(LAYOUT_PATH)
	if not gym_menu_layout is Dictionary:
		gym_menu_layout = {}

	var t_doc: Variant = _parse_json_file(TOURNAMENT_PATH)
	if t_doc is Dictionary:
		tournament_opponents = t_doc.get("opponents", [])


func _parse_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: invalid JSON %s" % path)
	return parsed


func get_gym(id: String) -> Dictionary:
	for g in gym_modes:
		if g.get("id", "") == id:
			return g
	return gym_modes[0] if gym_modes.size() > 0 else {}


func get_gym_orb_color(gym_id: String) -> Color:
	if GYM_ORB_COLORS.has(gym_id):
		return GYM_ORB_COLORS[gym_id] as Color
	return GYM_ORB_FALLBACK_COLOR


func get_gym_background_color(gym_id: String) -> Color:
	var orb: Color = get_gym_orb_color(gym_id)
	return Color(orb.r, orb.g, orb.b, 1.0).lerp(Color(0.97, 0.98, 0.99, 1.0), GYM_BACKGROUND_LIGHTEN)


func get_badge_texture(gym_id: String) -> Texture2D:
	if _badge_texture_cache.has(gym_id):
		return _badge_texture_cache[gym_id] as Texture2D
	var path: String = str(get_gym(gym_id).get("badge_texture", ""))
	if path.is_empty():
		_badge_texture_cache[gym_id] = null
		return null
	var tex: Resource = load(path)
	if tex is Texture2D:
		_badge_texture_cache[gym_id] = tex as Texture2D
		return _badge_texture_cache[gym_id] as Texture2D
	push_warning("GameData: missing badge texture at %s" % path)
	_badge_texture_cache[gym_id] = null
	return null


func get_power_def(type_id: String) -> Dictionary:
	for p in powers:
		if str(p.get("type", "")) == type_id:
			return p
	return {"type": type_id, "label": type_id, "description": ""}


func get_tournament_opponent(id: String) -> Dictionary:
	for o in tournament_opponents:
		if o.get("id", "") == id:
			return o
	return tournament_opponents[0] if tournament_opponents.size() > 0 else {}


func max_owned_powers_for_gym(gym_id: String) -> int:
	if gym_id == "twoSlots":
		return 2
	return int(gym_config.get("default_max_owned_powers", 3))


func is_countdown_gym(gym_id: String) -> bool:
	return gym_id == "countdownOne" or gym_id == "countdownAll"
