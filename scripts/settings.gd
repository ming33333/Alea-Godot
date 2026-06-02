extends Control

@onready var volume_slider: HSlider = %VolumeSlider


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		volume_slider.value = cfg.get_value("audio", "master", 1.0)


func _on_volume_changed(v: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", "master", v)
	cfg.save("user://settings.cfg")
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(v)
	)


func _on_back() -> void:
	SceneNav.go_to_main_menu()
