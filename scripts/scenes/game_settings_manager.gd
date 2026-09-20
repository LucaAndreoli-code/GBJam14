extends Node2D

@onready var _music_slider: SettingSlider = $Container/Menu/MusicSetting/SettingSlider
@onready var _sfx_slider: SettingSlider = $Container/Menu/SfxSetting/SettingSlider

@onready var _menu: Control = $Container/Menu

var _parent_payload: Dictionary
var _item_selected: int = 0

func _ready() -> void:
	GameState.set_paused(false)
	SignalBus.visibility_shader_toggled.emit(false)
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	_music_slider.set_value(GameState.get_music_level())
	_sfx_slider.set_value(GameState.get_sfx_level())
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		SceneManager.go_to(_parent_payload.get("scene_path"), _parent_payload)
		get_viewport().set_input_as_handled()
		return
	var dx := 0
	if event.is_action_pressed("dpad_right"):
		dx = 1
	elif event.is_action_pressed("dpad_left"):
		dx = -1
	if dx != 0:
		_change_selected_item_value(dx)
		return
	var dy := 0
	if event.is_action_pressed("dpad_down"):
		dy = 1
	elif event.is_action_pressed("dpad_up"):
		dy = -1
	if dy == 0:
		return
	get_viewport().set_input_as_handled()
	_move_list_selection(dy)

func on_scene_entered(payload: Dictionary) -> void:
	_parent_payload = payload

func _change_selected_item_value(dx: int) -> void:
	if _item_selected == 0:
		_music_slider.increase_value(1) if dx == 1 else _music_slider.decrease_value(1)
		GameState.set_music_level(_music_slider.get_value())
	elif _item_selected == 1:
		_sfx_slider.increase_value(1) if dx == 1 else _sfx_slider.decrease_value(1)
		GameState.set_sfx_level(_sfx_slider.get_value())
	elif _item_selected == 2:
		var palette_names: Array = Palette.get_all_palette_names()
		var current_palette_name := Palette.get_active_palette_name()
		var index := palette_names.find(current_palette_name)
		if index != -1:
			var new_index := index + dx
			if new_index >= 0 and new_index < palette_names.size():
				Palette.switch_to_palette(palette_names[new_index])
	AudioManager.play_sfx(AudioManager.ui_move_sound, -10.0)

func _move_list_selection(dy: int) -> void:
	var count := _menu.get_child_count()
	if count == 0:
		return
	var index := clampi(_item_selected + dy, 0, count - 1)
	if index == _item_selected:
		return
	_item_selected = index
	_refresh_ui()
	AudioManager.play_sfx(AudioManager.ui_move_sound, -10.0)

func _refresh_ui() -> void:
	for index in _menu.get_child_count():
		var item := _menu.get_child(index) as Control
		var icon := item.get_child(0) as TextureRect
		icon.self_modulate = Palette.SRC_LIGHTEST if index == _item_selected else Palette.SRC_DARK
