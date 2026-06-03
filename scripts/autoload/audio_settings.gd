extends Node
## Persists master volume and dice reroll SFX choice (user://settings.cfg).

const CFG_PATH := "user://settings.cfg"
const DEFAULT_DICE_SOUND := "default"

const DICE_SOUND_PATHS: Dictionary = {
	"default": "res://assets/dice_roll_default.mp3",
	"roll_2": "res://assets/dice_roll_2.mp3",
	"roll_3": "res://assets/dice_roll3.mp3",
}

const DICE_SOUND_ORDER: Array[String] = ["default", "roll_2", "roll_3"]

var dice_roll_sound_id: String = DEFAULT_DICE_SOUND
var _preview_player: AudioStreamPlayer


func _ready() -> void:
	load_settings()
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = &"Master"
	add_child(_preview_player)


func _load_or_create_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	return cfg


func get_master_volume_linear() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return 1.0
	return float(cfg.get_value("audio", "master", 1.0))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		apply_master_volume(1.0)
		dice_roll_sound_id = DEFAULT_DICE_SOUND
		return
	apply_master_volume(float(cfg.get_value("audio", "master", 1.0)))
	var saved: String = str(cfg.get_value("audio", "dice_roll_sound", DEFAULT_DICE_SOUND))
	dice_roll_sound_id = saved if DICE_SOUND_PATHS.has(saved) else DEFAULT_DICE_SOUND


func apply_master_volume(linear: float) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func save_master_volume(linear: float) -> void:
	var cfg := _load_or_create_cfg()
	cfg.set_value("audio", "master", linear)
	cfg.save(CFG_PATH)
	apply_master_volume(linear)


func save_dice_roll_sound(sound_id: String) -> void:
	if not DICE_SOUND_PATHS.has(sound_id):
		return
	dice_roll_sound_id = sound_id
	var cfg := _load_or_create_cfg()
	cfg.set_value("audio", "dice_roll_sound", sound_id)
	cfg.save(CFG_PATH)


func get_dice_roll_stream_for_id(sound_id: String) -> AudioStream:
	if not DICE_SOUND_PATHS.has(sound_id):
		return null
	var path: String = str(DICE_SOUND_PATHS[sound_id])
	var stream: Resource = load(path)
	if stream is AudioStream:
		return stream as AudioStream
	push_warning("AudioSettings: missing dice roll sound at %s" % path)
	return null


func get_dice_roll_stream() -> AudioStream:
	return get_dice_roll_stream_for_id(dice_roll_sound_id)


func preview_dice_roll_sound(sound_id: String) -> void:
	if _preview_player == null:
		return
	var stream: AudioStream = get_dice_roll_stream_for_id(sound_id)
	if stream == null:
		return
	_preview_player.stream = stream
	_preview_player.play()


static func dice_sound_label(sound_id: String) -> String:
	match sound_id:
		"default":
			return "Default"
		"roll_2":
			return "Roll 2"
		"roll_3":
			return "Roll 3"
		_:
			return sound_id
