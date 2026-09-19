extends Node2D

const LEVEL_SEL_SCENE_PATH: String = "res://scenes/game/level_selection.tscn"

@onready var _splash_screen: Control = $SplashScreen
@onready var _splash_screen_anim: AnimatedSprite2D = $SplashScreen/Animation
@onready var _logo: Sprite2D = $Logo
@onready var _character: AnimatedSprite2D = $CharAnimated
@onready var _menu: VBoxContainer = $Container/Menu

var _item_selected: int = 0
var _is_input_enabled: bool = false

func _ready() -> void:
	SignalBus.visibility_shader_toggled.emit(false)
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	await get_tree().create_timer(1.5).timeout
	_splash_screen_anim.play("default")
	_splash_screen_anim.animation_finished.connect(_on_splash_screen_finished)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_input_enabled:
		return
	if event.is_action_pressed("btn_a"):
		if _item_selected == 0:
			SceneManager.go_to(LEVEL_SEL_SCENE_PATH)
		elif _item_selected == 1:
			pass
		return
	var dy := 0
	if event.is_action_pressed("dpad_down"):
		dy = 1
	elif event.is_action_pressed("dpad_up"):
		dy = -1
	if dy == 0:
		return
	_move_list_selection(dy)

func _on_splash_screen_finished():
	_splash_screen.visible = false
	var logo_move_tween := create_tween()
	logo_move_tween.tween_property(_logo, "global_position", Vector2(10.0, 1.0), 1.0)
	await logo_move_tween.finished
	var char_tween := create_tween()
	var fade_colors := [
		Palette.SRC_DARK, 
		Palette.SRC_LIGHT, 
		Palette.SRC_LIGHTEST
	]
	for c in fade_colors:
		char_tween.tween_callback(_character.set.bind("self_modulate", c))
		char_tween.tween_interval(0.2)
	await char_tween.finished
	await get_tree().create_timer(1.5).timeout
	var char_move_tween := create_tween()
	char_move_tween.tween_property(_character, "global_position", Vector2(60.0, 32.0), 1.0)
	await char_move_tween.finished
	_menu.visible = true
	_refresh_ui()
	_is_input_enabled = true

func _refresh_ui() -> void:
	for index in _menu.get_child_count():
		var label := _menu.get_child(index) as Label
		var color := Palette.SRC_LIGHTEST
		if index == _item_selected:
			color = Palette.SRC_LIGHT
		label.add_theme_color_override("font_color", color)

func _move_list_selection(dy: int) -> void:
	var count := _menu.get_child_count()
	if count == 0:
		return
	var index := clampi(_item_selected + dy, 0, count - 1)
	if index == _item_selected:
		return
	_item_selected = index
	_refresh_ui()
