extends Node
## Toggle with ProjectSettings or set enabled = false for release builds.
## All lines print to Godot Output (filter by "Alea").

var enabled: bool = true


func _ready() -> void:
	alea_log("DebugLog", "enabled=%s" % enabled)


func alea_log(tag: String, message: String) -> void:
	if not enabled:
		return
	print("[Alea/%s] %s" % [tag, message])


## Back-compat alias (avoid calling bare log() inside this script — clashes with Node.log).
func log(tag: String, message: String) -> void:
	alea_log(tag, message)


func log_error(tag: String, message: String) -> void:
	var line := "[Alea/ERROR/%s] %s" % [tag, message]
	print(line)
	push_error(line)


func mouse_filter_name(filter: Control.MouseFilter) -> String:
	match filter:
		Control.MOUSE_FILTER_STOP:
			return "STOP"
		Control.MOUSE_FILTER_PASS:
			return "PASS"
		Control.MOUSE_FILTER_IGNORE:
			return "IGNORE"
		_:
			return "UNKNOWN(%d)" % int(filter)
