extends Node
## Persists master/music volume, background playlist, and dice reroll SFX (user://settings.cfg).

const CFG_PATH := "user://settings.cfg"
const DEFAULT_DICE_SOUND := "roll_2"
const MUSIC_BUS := &"Music"

const DICE_SOUND_PATHS: Dictionary = {
	"default": "res://assets/sfx/dice_roll_default.mp3",
	"roll_2": "res://assets/sfx/dice_roll_2.mp3",
	"roll_3": "res://assets/sfx/dice_roll3.mp3",
}

const DICE_SOUND_ORDER: Array[String] = ["default", "roll_2", "roll_3"]
const DICE_SWISH_PATH := "res://assets/sfx/thud.mp3"

const MUSIC_TRACKS: Array[String] = [
	"res://assets/music/pause_and_breathe.mp3",
	"res://assets/music/slow_sleep_state.mp3",
	"res://assets/music/slow_jazzy_sleep_state.mp3",
	"res://assets/music/Highlife Fusion.mp3",
]

var dice_roll_sound_id: String = DEFAULT_DICE_SOUND
var music_volume_linear: float = 1.0
var music_muted: bool = false

var _preview_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_track_index: int = 0


func _ready() -> void:
	_ensure_music_bus()
	load_settings()
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = &"Master"
	add_child(_preview_player)
	_setup_music_player()
	start_background_music()


func _load_or_create_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	return cfg


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, &"Master")


func _music_bus_index() -> int:
	return AudioServer.get_bus_index(MUSIC_BUS)


func get_master_volume_linear() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return 1.0
	return float(cfg.get_value("audio", "master", 1.0))


func get_music_volume_linear() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return 1.0
	return float(cfg.get_value("audio", "music", 1.0))


func is_music_muted() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return false
	return bool(cfg.get_value("audio", "music_muted", false))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		apply_master_volume(1.0)
		music_volume_linear = 1.0
		music_muted = false
		dice_roll_sound_id = DEFAULT_DICE_SOUND
		apply_music_settings()
		return
	apply_master_volume(float(cfg.get_value("audio", "master", 1.0)))
	music_volume_linear = float(cfg.get_value("audio", "music", 1.0))
	music_muted = bool(cfg.get_value("audio", "music_muted", false))
	var saved: String = str(cfg.get_value("audio", "dice_roll_sound", DEFAULT_DICE_SOUND))
	dice_roll_sound_id = saved if DICE_SOUND_PATHS.has(saved) else DEFAULT_DICE_SOUND
	apply_music_settings()


func apply_master_volume(linear: float) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func apply_music_settings() -> void:
	var idx: int = _music_bus_index()
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume_linear))
	AudioServer.set_bus_mute(idx, music_muted)
	if _music_player != null and music_muted:
		_music_player.stop()


func save_master_volume(linear: float) -> void:
	var cfg := _load_or_create_cfg()
	cfg.set_value("audio", "master", linear)
	cfg.save(CFG_PATH)
	apply_master_volume(linear)


func save_music_volume(linear: float) -> void:
	music_volume_linear = clampf(linear, 0.0, 1.0)
	var cfg := _load_or_create_cfg()
	cfg.set_value("audio", "music", music_volume_linear)
	cfg.save(CFG_PATH)
	apply_music_settings()


func save_music_muted(muted: bool) -> void:
	var was_muted: bool = music_muted
	music_muted = muted
	var cfg := _load_or_create_cfg()
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.save(CFG_PATH)
	apply_music_settings()
	if was_muted and not music_muted:
		_advance_music_track()
		_play_current_music_track()


func save_dice_roll_sound(sound_id: String) -> void:
	if not DICE_SOUND_PATHS.has(sound_id):
		return
	dice_roll_sound_id = sound_id
	var cfg := _load_or_create_cfg()
	cfg.set_value("audio", "dice_roll_sound", sound_id)
	cfg.save(CFG_PATH)


func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.finished.connect(_on_music_track_finished)
	add_child(_music_player)


func start_background_music() -> void:
	if MUSIC_TRACKS.is_empty():
		return
	_music_track_index = _pick_random_music_index()
	_play_current_music_track()


func _play_current_music_track() -> void:
	if _music_player == null or MUSIC_TRACKS.is_empty() or music_muted:
		return
	var path: String = MUSIC_TRACKS[_music_track_index]
	var stream: Resource = load(path)
	if stream is AudioStream:
		_music_player.stream = stream as AudioStream
		_music_player.play()
		return
	push_warning("AudioSettings: missing music at %s" % path)
	_advance_music_track()
	_play_current_music_track()


func _on_music_track_finished() -> void:
	_advance_music_track()
	_play_current_music_track()


func _advance_music_track() -> void:
	if MUSIC_TRACKS.is_empty():
		return
	_music_track_index = _pick_random_music_index(_music_track_index)


func _pick_random_music_index(exclude_index: int = -1) -> int:
	if MUSIC_TRACKS.size() == 1:
		return 0
	var next: int = randi() % MUSIC_TRACKS.size()
	while next == exclude_index:
		next = randi() % MUSIC_TRACKS.size()
	return next


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


func get_dice_swish_stream() -> AudioStream:
	var stream: Resource = load(DICE_SWISH_PATH)
	if stream is AudioStream:
		return stream as AudioStream
	push_warning("AudioSettings: missing dice swish sound at %s" % DICE_SWISH_PATH)
	return null


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
