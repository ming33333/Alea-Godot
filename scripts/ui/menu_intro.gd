class_name MenuIntro
extends Control

signal intro_finished

const INTRO_CONFIG := preload("res://scripts/ui/intros/menu_intro_config.gd")
const TITLE_HOLD_SEC := 0.85
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


func play(_title_target: Label) -> void:
	if INTRO_CONFIG.USE_INTRO_1:
		await _play_intro_1(_title_target)
	else:
		await _play_title_reveal()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_finished.emit()


func _play_title_reveal() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.modulate = Color.WHITE
	await get_tree().process_frame
	await get_tree().create_timer(TITLE_HOLD_SEC).timeout
	var tween := create_tween()
	tween.tween_property(_backdrop, "modulate:a", 0.0, BACKDROP_FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_backdrop.modulate.a = 1.0


func _play_intro_1(_title_target: Label) -> void:
	push_warning(
		"MenuIntro: intro 1 is archived. Point IntroOverlay to scripts/ui/intros/menu_intro_1.gd to restore."
	)
	await _play_title_reveal()
