extends Node
## Dice face textures: pixel font (VT323) or pip style (dice). Lucky 7 always uses dice_face_7.

signal style_changed

const CFG_PATH := "user://settings.cfg"
const STYLE_PIPES := "dice"
const STYLE_PIXEL := "pixel"
const DEFAULT_STYLE := STYLE_PIXEL
const VT323_FONT_PATH := "res://assets/fonts/VT323/VT323-Regular.ttf"
const LEGACY_NUM_STYLE := "dice_num"

const STYLE_ORDER: Array[String] = [STYLE_PIXEL, STYLE_PIPES]

const PIPES_FACE_PATHS: Array[String] = [
	"",
	"res://assets/dice/die_face_1.png",
	"res://assets/dice/die_face_2.png",
	"res://assets/dice/die_face_3.png",
	"res://assets/dice/die_face_4.png",
	"res://assets/dice/die_face_5.png",
	"res://assets/dice/die_face_6.png",
]

const LUCKY_SEVEN_PATH := "res://assets/dice/dice_face_7.png"

var dice_style_id: String = DEFAULT_STYLE

var _lucky_seven_tex: Texture2D
var _pipes_faces: Array[Texture2D] = []
var _pixel_font: Font


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		dice_style_id = DEFAULT_STYLE
		return
	var saved: String = str(cfg.get_value("visual", "dice_style", DEFAULT_STYLE))
	if saved == LEGACY_NUM_STYLE:
		saved = STYLE_PIXEL
	dice_style_id = saved if STYLE_ORDER.has(saved) else DEFAULT_STYLE


func get_dice_style_id() -> String:
	return dice_style_id


func save_dice_style(style_id: String) -> void:
	if not STYLE_ORDER.has(style_id):
		return
	if dice_style_id == style_id:
		return
	dice_style_id = style_id
	_pipes_faces.clear()
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("visual", "dice_style", style_id)
	cfg.save(CFG_PATH)
	style_changed.emit()


func is_pixel_font_style() -> bool:
	return dice_style_id == STYLE_PIXEL


func get_pixel_font() -> Font:
	if _pixel_font == null:
		var res: Resource = load(VT323_FONT_PATH)
		if res is Font:
			_pixel_font = res as Font
		else:
			push_warning("DiceSprites: missing pixel font at %s" % VT323_FONT_PATH)
	return _pixel_font


func get_face(value: int) -> Texture2D:
	if value == 7:
		return _lucky_seven_face()
	if value < 1 or value > 6:
		return null
	if is_pixel_font_style():
		return null
	return _faces_for_style()[value]


func _lucky_seven_face() -> Texture2D:
	if _lucky_seven_tex == null:
		var res: Resource = load(LUCKY_SEVEN_PATH)
		if res is Texture2D:
			_lucky_seven_tex = res as Texture2D
		else:
			push_warning("DiceSprites: missing lucky seven face at %s" % LUCKY_SEVEN_PATH)
	return _lucky_seven_tex


func _faces_for_style() -> Array[Texture2D]:
	return _load_face_set(PIPES_FACE_PATHS, _pipes_faces)


func _load_face_set(paths: Array[String], cache: Array[Texture2D]) -> Array[Texture2D]:
	if cache.size() > 6:
		return cache
	cache.clear()
	cache.append(null)
	for i in range(1, 7):
		var path: String = paths[i]
		var res: Resource = load(path)
		if res is Texture2D:
			cache.append(res as Texture2D)
		else:
			push_warning("DiceSprites: missing face at %s" % path)
			cache.append(null)
	return cache


static func style_label(style_id: String) -> String:
	match style_id:
		STYLE_PIPES:
			return "Pip dice"
		STYLE_PIXEL:
			return "Pixel font dice"
		_:
			return style_id
