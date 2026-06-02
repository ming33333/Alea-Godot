extends Control

const GRID_SIZE := 5

@onready var status: Label = $Margin/VBox/Header/Status
@onready var hud: Label = $Margin/VBox/Header/Hud
@onready var grid: GridContainer = $Margin/VBox/GridPanel/GridMargin/Grid
@onready var back_button: Button = $Margin/VBox/Back


func _ready() -> void:
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	_build_grid()
	_update_hud()
	status.text = "Prototype grid — port rules from ../Alea"


func _build_grid() -> void:
	grid.columns = GRID_SIZE
	for _row in GRID_SIZE:
		for _col in GRID_SIZE:
			var die := Button.new()
			die.custom_minimum_size = Vector2(72, 72)
			die.text = str(randi_range(1, 6))
			die.focus_mode = Control.FOCUS_NONE
			grid.add_child(die)


func _update_hud() -> void:
	hud.text = (
		"Level %d  ·  Hearts %d  ·  Switches %d  ·  Rerolls %d"
		% [GameState.level, GameState.hearts, GameState.switches, GameState.rerolls]
	)


func _on_back_pressed() -> void:
	SceneNav.go_to_main_menu()
