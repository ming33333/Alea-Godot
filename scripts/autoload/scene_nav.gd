extends Node

signal change_failed(message: String)
signal change_succeeded(scene_path: String)

const MAIN_MENU: PackedScene = preload("res://scenes/main_menu.tscn")
const GAME: PackedScene = preload("res://scenes/game.tscn")
const TOURNAMENT_PICK: PackedScene = preload("res://scenes/tournament_pick.tscn")
const TOURNAMENT_PREVIEW: PackedScene = preload("res://scenes/tournament_preview.tscn")
const SETTINGS: PackedScene = preload("res://scenes/settings.tscn")

var _change_seq: int = 0


func go_to_main_menu(skip_intro: bool = true) -> void:
	GameState.skip_menu_intro = skip_intro
	_change(MAIN_MENU)


func go_to_game() -> void:
	_change(GAME)


func go_to_tournament_pick() -> void:
	_change(TOURNAMENT_PICK)


func go_to_tournament_preview() -> void:
	_change(TOURNAMENT_PREVIEW)


func go_to_settings() -> void:
	_change(SETTINGS)


func _change(scene: PackedScene) -> void:
	_change_seq += 1
	var seq := _change_seq
	call_deferred("_do_change", scene, seq)


func _do_change(scene: PackedScene, seq: int) -> void:
	var tree := get_tree()
	if tree == null:
		change_failed.emit("no tree")
		return
	var err: Error = tree.change_scene_to_packed(scene)
	if err != OK:
		change_failed.emit(error_string(err))
		return
	change_succeeded.emit(scene.resource_path)
