class_name DraggablePanel
extends PanelContainer

@export var drag_handle: NodePath

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _user_moved: bool = false


func _ready() -> void:
	var handle := _get_drag_handle()
	if handle == null:
		return
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	if not handle.gui_input.is_connected(_on_drag_handle_gui_input):
		handle.gui_input.connect(_on_drag_handle_gui_input)


func reset_drag_state() -> void:
	_dragging = false
	_user_moved = false


func ensure_centered() -> void:
	if _user_moved:
		return
	call_deferred("_apply_centered")


func _apply_centered() -> void:
	if _user_moved:
		return
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_size()
	position = (parent_ctrl.size - size) * 0.5
	_clamp_to_parent()


func _get_drag_handle() -> Control:
	if drag_handle.is_empty():
		return self
	return get_node_or_null(drag_handle) as Control


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dragging = true
			_user_moved = true
			_drag_offset = global_position - mb.global_position
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		global_position = mm.global_position + _drag_offset
		_clamp_to_parent()


func _clamp_to_parent() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return
	var margin := 8.0
	var parent_rect := Rect2(Vector2.ZERO, parent_ctrl.size)
	var max_pos := parent_rect.size - size
	position.x = clampf(position.x, margin, maxf(max_pos.x, margin))
	position.y = clampf(position.y, margin, maxf(max_pos.y, margin))
