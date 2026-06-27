class_name MenuIntro
extends Control

signal intro_finished

const INTRO_CONFIG := preload("res://scripts/ui/intros/menu_intro_config.gd")
const TITLE_HOLD_SEC := 0.85
const TITLE_RISE_SEC := 1.35
const BACKDROP_FADE_SEC := 1.8

@onready var _backdrop: ColorRect = %IntroBackdrop


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%IntroTextViewport.visible = false


func show_backdrop() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.modulate = Color.WHITE


func play(title_target: Label) -> void:
	if INTRO_CONFIG.USE_INTRO_1:
		await _play_intro_1(title_target)
	else:
		await _play_title_reveal(title_target)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_finished.emit()


func _play_title_reveal(title_target: Label) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.modulate = Color.WHITE
	await get_tree().process_frame
	await get_tree().process_frame
	if title_target == null:
		await _fade_out_backdrop()
		return
	var end_global: Vector2 = title_target.global_position
	var center_global: Vector2 = _screen_center_for(title_target)
	title_target.top_level = true
	title_target.z_index = 91
	title_target.global_position = center_global
	await get_tree().create_timer(TITLE_HOLD_SEC).timeout
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_target, "global_position", end_global, TITLE_RISE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_backdrop, "modulate:a", 0.0, BACKDROP_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_settle_title(title_target)
	_backdrop.modulate.a = 1.0


func _screen_center_for(label: Control) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(
		viewport_size.x * 0.5 - label.size.x * 0.5,
		viewport_size.y * 0.5 - label.size.y * 0.5
	)


func _settle_title(title_target: Label) -> void:
	title_target.top_level = false
	title_target.z_index = 0
	title_target.position = Vector2.ZERO


func _fade_out_backdrop() -> void:
	var tween := create_tween()
	tween.tween_property(_backdrop, "modulate:a", 0.0, BACKDROP_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_backdrop.modulate.a = 1.0


func _play_intro_1(title_target: Label) -> void:
	push_warning(
		"MenuIntro: intro 1 is archived. Point IntroOverlay to scripts/ui/intros/menu_intro_1.gd to restore."
	)
	await _play_title_reveal(title_target)
