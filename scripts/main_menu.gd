extends Control

@onready var subtitle: Label = $Margin/VBox/Subtitle
@onready var prototype_hint: Label = $Margin/VBox/PrototypeHint
@onready var play_button: Button = $Margin/VBox/Play
@onready var error_label: Label = $Margin/VBox/ErrorLabel


func _ready() -> void:
	subtitle.text = "Godot port — tap Play to open the grid"
	prototype_hint.text = "Full game spec: ../Alea (web prototype)"
	error_label.hide()
	# Code connection so Play works even if the .tscn signal link is missing.
	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if not SceneNav.change_failed.is_connected(_on_scene_change_failed):
		SceneNav.change_failed.connect(_on_scene_change_failed)


func _on_play_pressed() -> void:
	error_label.hide()
	play_button.disabled = true
	GameState.reset_run()
	SceneNav.go_to_game()


func _on_scene_change_failed(message: String) -> void:
	play_button.disabled = false
	error_label.text = message
	error_label.show()
