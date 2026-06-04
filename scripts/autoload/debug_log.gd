extends Node
## Toggle with ProjectSettings or set enabled = false for release builds.
## All lines print to Godot Output (filter by "Alea").

var enabled: bool = true
var log_mouse_clicks: bool = true
var log_menu_clicks: bool = true


func _ready() -> void:
	alea_log("DebugLog", "enabled=%s menu_clicks=%s" % [enabled, log_menu_clicks])


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


func describe_control(node: Node) -> String:
	if node == null:
		return "(none)"
	if node is Control:
		var c := node as Control
		var disabled_note: String = "n/a"
		if c is BaseButton:
			disabled_note = str((c as BaseButton).disabled)
		return "%s/%s filter=%s visible=%s disabled=%s" % [
			c.get_class(),
			c.name,
			mouse_filter_name(c.mouse_filter),
			c.visible,
			disabled_note,
		]
	return "%s/%s" % [node.get_class(), node.name]


func control_path(node: Node) -> String:
	if node == null:
		return "(none)"
	var parts: PackedStringArray = []
	var cur: Node = node
	while cur != null:
		parts.insert(0, cur.name)
		cur = cur.get_parent()
	return "/".join(parts)


func log_hovered(tag: String, prefix: String) -> void:
	if not enabled or not log_menu_clicks:
		return
	var tree := Engine.get_main_loop()
	if tree == null or not tree is SceneTree:
		return
	var st := tree as SceneTree
	if st.root == null:
		return
	var viewport := st.root.get_viewport()
	var hovered: Control = viewport.gui_get_hovered_control()
	alea_log(tag, "%s mouse=%s hovered=%s path=%s" % [
		prefix,
		viewport.get_mouse_position(),
		describe_control(hovered),
		control_path(hovered),
	])
