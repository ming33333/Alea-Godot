extends Control

@onready var volume_slider: HSlider = %VolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var music_mute: CheckBox = %MusicMute
@onready var dice_style_option: OptionButton = %DiceStyleOption
@onready var dice_sound_option: OptionButton = %DiceSoundOption
@onready var cheat_status: Label = %CheatStatus
@onready var cheat_code_input: LineEdit = %CheatCodeInput
@onready var reset_confirm: ConfirmationDialog = %ResetConfirm
@onready var reset_status: Label = %ResetStatus

var _dice_style_ids: Array[String] = []
var _dice_sound_ids: Array[String] = []


func _ready() -> void:
	AudioSettings.load_settings()
	volume_slider.value = AudioSettings.get_master_volume_linear()
	music_volume_slider.value = AudioSettings.get_music_volume_linear()
	music_mute.button_pressed = AudioSettings.is_music_muted()
	_populate_dice_style_options()
	_populate_dice_sound_options()
	_refresh_cheat_ui()
	if not DevCheats.unlock_state_changed.is_connected(_refresh_cheat_ui):
		DevCheats.unlock_state_changed.connect(_refresh_cheat_ui)


func _populate_dice_style_options() -> void:
	dice_style_option.clear()
	_dice_style_ids.clear()
	for style_id in DiceSprites.STYLE_ORDER:
		_dice_style_ids.append(style_id)
		dice_style_option.add_item(DiceSprites.style_label(style_id))
	var style_idx: int = _dice_style_ids.find(DiceSprites.get_dice_style_id())
	if style_idx < 0:
		style_idx = 0
	dice_style_option.set_block_signals(true)
	dice_style_option.select(style_idx)
	dice_style_option.set_block_signals(false)


func _populate_dice_sound_options() -> void:
	dice_sound_option.clear()
	_dice_sound_ids.clear()
	for sound_id in AudioSettings.DICE_SOUND_ORDER:
		_dice_sound_ids.append(sound_id)
		dice_sound_option.add_item(AudioSettings.dice_sound_label(sound_id))
	var idx: int = _dice_sound_ids.find(AudioSettings.dice_roll_sound_id)
	if idx < 0:
		idx = 0
	dice_sound_option.set_block_signals(true)
	dice_sound_option.select(idx)
	dice_sound_option.set_block_signals(false)


func _refresh_cheat_ui() -> void:
	cheat_status.text = DevCheats.get_status_text()


func _on_volume_changed(v: float) -> void:
	AudioSettings.save_master_volume(v)


func _on_music_volume_changed(v: float) -> void:
	AudioSettings.save_music_volume(v)


func _on_music_mute_toggled(pressed: bool) -> void:
	AudioSettings.save_music_muted(pressed)


func _on_dice_style_selected(index: int) -> void:
	if index < 0 or index >= _dice_style_ids.size():
		return
	DiceSprites.save_dice_style(_dice_style_ids[index])


func _on_dice_sound_selected(index: int) -> void:
	if index < 0 or index >= _dice_sound_ids.size():
		return
	var sound_id: String = _dice_sound_ids[index]
	AudioSettings.save_dice_roll_sound(sound_id)
	AudioSettings.preview_dice_roll_sound(sound_id)


func _on_cheat_apply_pressed() -> void:
	_try_apply_cheat_code()


func _on_cheat_code_submitted(_text: String) -> void:
	_try_apply_cheat_code()


func _try_apply_cheat_code() -> void:
	var code: String = cheat_code_input.text
	if DevCheats.try_unlock(code):
		cheat_status.text = "Unlocked! Dev menu shows in-game (and in editor if enabled)."
		cheat_code_input.text = ""
	else:
		cheat_status.text = "Invalid code."
	_refresh_cheat_ui()


func _on_cheat_lock_pressed() -> void:
	DevCheats.lock_cheats()
	cheat_status.text = "Dev cheats locked."
	_refresh_cheat_ui()


func _on_reset_data_pressed() -> void:
	reset_status.text = ""
	reset_confirm.popup_centered()


func _on_reset_confirmed() -> void:
	SaveService.reset_all_user_data()
	_reload_settings_ui()
	reset_status.text = (
		"Progress reset. Challenge orb badges, Dice Master title, map layout, "
		+ "and settings were cleared."
	)


func _reload_settings_ui() -> void:
	AudioSettings.load_settings()
	volume_slider.value = AudioSettings.get_master_volume_linear()
	music_volume_slider.value = AudioSettings.get_music_volume_linear()
	music_mute.button_pressed = AudioSettings.is_music_muted()
	_populate_dice_style_options()
	_populate_dice_sound_options()
	_refresh_cheat_ui()


func _on_back() -> void:
	SceneNav.go_to_main_menu()
