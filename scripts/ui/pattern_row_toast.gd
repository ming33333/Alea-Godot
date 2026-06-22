class_name PatternRowToast
extends Control

const SLIDE_IN_SEC := 0.24
const HOLD_SEC := 0.52
const FADE_OUT_SEC := 0.36
const SLIDE_OFFSET := 42.0
const ROW_GAP := 10.0

var _panel: PanelContainer
var _tween: Tween


static func spawn(
	parent: Control,
	pattern_name: String,
	row_rect: Rect2,
	prefer_right: bool
) -> PatternRowToast:
	var toast := PatternRowToast.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 45
	parent.add_child(toast)
	toast._build_ui(pattern_name)
	toast._run_animation(row_rect, prefer_right)
	return toast


func _build_ui(pattern_name: String) -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.24, 0.94)
	style.border_color = Color(0.55, 0.68, 0.82, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = pattern_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1))
	_panel.add_child(label)
	add_child(_panel)


func _run_animation(row_rect: Rect2, from_right: bool) -> void:
	call_deferred("_deferred_run_animation", row_rect, from_right)


func _deferred_run_animation(row_rect: Rect2, from_right: bool) -> void:
	if not is_inside_tree() or _panel == null:
		queue_free()
		return
	_panel.reset_size()
	var toast_size: Vector2 = _panel.size
	if toast_size.x <= 0.0:
		toast_size = Vector2(96, 28)
	var row_center_y: float = row_rect.position.y + row_rect.size.y * 0.5
	var final_global: Vector2
	var start_global: Vector2
	if from_right:
		final_global = Vector2(
			row_rect.position.x + row_rect.size.x + ROW_GAP,
			row_center_y - toast_size.y * 0.5
		)
		start_global = final_global + Vector2(SLIDE_OFFSET, 0.0)
	else:
		final_global = Vector2(
			row_rect.position.x - toast_size.x - ROW_GAP,
			row_center_y - toast_size.y * 0.5
		)
		start_global = final_global - Vector2(SLIDE_OFFSET, 0.0)

	global_position = start_global
	modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(
		self, "global_position", final_global, SLIDE_IN_SEC
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, SLIDE_IN_SEC * 0.7)
	_tween.chain()
	_tween.tween_interval(HOLD_SEC)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.finished.connect(queue_free)
