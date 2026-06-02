extends Node
## Reliable scene changes (deferred + preloaded) for menu ↔ game.

signal change_failed(message: String)

const MAIN_MENU: PackedScene = preload("res://scenes/main_menu.tscn")
const GAME: PackedScene = preload("res://scenes/game.tscn")


func go_to_main_menu() -> void:
	_change(MAIN_MENU)


func go_to_game() -> void:
	_change(GAME)


func _change(scene: PackedScene) -> void:
	call_deferred("_do_change", scene)


func _do_change(scene: PackedScene) -> void:
	var tree := get_tree()
	if tree == null:
		push_error("SceneNav: no SceneTree")
		return
	var err := tree.change_scene_to_packed(scene)
	if err != OK:
		var msg := "Failed to load %s (%s)" % [scene.resource_path, error_string(err)]
		push_error("SceneNav: %s" % msg)
		change_failed.emit(msg)
