extends Node
## Dev cheat menu unlock. Edit unlock codes in res://data/dev_cheats.json

signal unlock_state_changed(unlocked: bool)

const CONFIG_PATH := "res://data/dev_cheats.json"
const SAVE_PATH := "user://dev_cheats_unlocked.dat"

var unlock_codes: Array[String] = []
var always_on_in_editor: bool = true
var persist_unlock: bool = true
var hint: String = ""

var unlocked: bool = false
var menu_minimized: bool = false

var _type_buffer: String = ""
var _buffer_timer: Timer


func _ready() -> void:
	_load_config()
	_load_persisted_unlock()
	_buffer_timer = Timer.new()
	_buffer_timer.one_shot = true
	_buffer_timer.wait_time = 4.0
	_buffer_timer.timeout.connect(_clear_type_buffer)
	add_child(_buffer_timer)
	if always_on_in_editor and Engine.is_editor_hint():
		unlocked = true
	DebugLog.log("DevCheats", "ready codes=%d unlocked=%s active=%s" % [
		unlock_codes.size(), unlocked, is_active()
	])


func _load_config() -> void:
	unlock_codes = []
	always_on_in_editor = true
	persist_unlock = true
	hint = ""
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("DevCheats: missing %s — using defaults" % CONFIG_PATH)
		unlock_codes = ["alea", "devmode", "wrench"]
		return
	var text: String = FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("DevCheats: invalid JSON in %s" % CONFIG_PATH)
		unlock_codes = ["alea"]
		return
	var doc: Dictionary = parsed
	for code in doc.get("unlock_codes", []):
		unlock_codes.append(_normalize_code(str(code)))
	always_on_in_editor = bool(doc.get("always_on_in_editor", true))
	persist_unlock = bool(doc.get("persist_unlock", true))
	hint = str(doc.get("hint", ""))


func _load_persisted_unlock() -> void:
	if not persist_unlock:
		return
	if FileAccess.file_exists(SAVE_PATH):
		unlocked = FileAccess.get_file_as_string(SAVE_PATH).strip_edges() == "1"


func _save_persisted_unlock() -> void:
	if not persist_unlock:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string("1" if unlocked else "0")


func is_active() -> bool:
	if unlocked:
		return true
	if always_on_in_editor and Engine.is_editor_hint():
		return true
	return OS.is_debug_build()


func try_unlock(raw: String) -> bool:
	var code: String = _normalize_code(raw)
	if code.is_empty():
		return false
	if code not in unlock_codes:
		return false
	if unlocked:
		return true
	unlocked = true
	_save_persisted_unlock()
	unlock_state_changed.emit(true)
	DebugLog.log("DevCheats", "unlocked with code")
	return true


func lock_cheats() -> void:
	if not unlocked:
		return
	unlocked = false
	_save_persisted_unlock()
	unlock_state_changed.emit(false)


func feed_typed_key(key_unicode: int) -> bool:
	if key_unicode == 0:
		return false
	var ch: String = char(key_unicode)
	if ch.length() != 1:
		return false
	if not _is_code_char(ch):
		return false
	_type_buffer += ch.to_lower()
	_buffer_timer.start()
	if _type_buffer.length() > 32:
		_type_buffer = _type_buffer.substr(_type_buffer.length() - 32)
	for code in unlock_codes:
		if _type_buffer.ends_with(code):
			_clear_type_buffer()
			return try_unlock(code)
	return false


func _clear_type_buffer() -> void:
	_type_buffer = ""


func _normalize_code(raw: String) -> String:
	return raw.strip_edges().to_lower()


func _is_code_char(ch: String) -> bool:
	var c: int = ch.unicode_at(0)
	return (c >= 97 and c <= 122) or (c >= 48 and c <= 57)


func get_status_text() -> String:
	if is_active():
		if Engine.is_editor_hint() and always_on_in_editor and not unlocked:
			return "Dev cheats ON (editor). Codes in data/dev_cheats.json also work."
		return "Dev cheats unlocked."
	return "Locked. Enter a code below or type one on the menu / in-game."


func get_codes_hint_for_settings() -> String:
	if unlock_codes.is_empty():
		return "Add unlock_codes to res://data/dev_cheats.json"
	return "Codes: %s" % ", ".join(unlock_codes)
