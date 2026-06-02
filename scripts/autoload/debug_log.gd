extends Node
## Toggle with ProjectSettings or set enabled = false for release builds.
## All lines print to Godot Output (filter by "Alea").

var enabled: bool = true
var log_mouse_clicks: bool = true


func log(tag: String, message: String) -> void:
	if not enabled:
		return
	print("[Alea/%s] %s" % [tag, message])


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
