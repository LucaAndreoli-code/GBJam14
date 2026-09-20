class_name PauseMenuManager
extends Node2D

const INVENTORY_SCENE_PATH: String = "res://scenes/game/inventory.tscn"
const SETTINGS_SCENE_PATH: String = "res://scenes/game/game_settings.tscn"
const LEVEL_SEL_SCENE_PATH: String = "res://scenes/game/level_selection.tscn"

## Owns the whole pause toggle: a scene gets pause simply by mounting this menu, and a scene that
## does not mount it - the map, the inventory - stays unpausable. The menu needs no process_mode of
## its own: GameState freezes the game scene alone, see SceneManager._apply_pause().
@export var menu_items: Array[PauseMenuItem] = []

@onready var _menu_list: VBoxContainer = $Frame/Container/Menu/List

var _scene_path: String
var _player: PlayerDungeonController
var _item_selected: int = 0
# Entries switched off by whoever mounts the menu, for this instance alone: the PauseMenuItem
# resources are sub-resources shared by every instance of the scene, see pause_menu.tscn.
var _runtime_disabled: Dictionary[StringName, bool] = {}

func setup(scene_path: String, player: PlayerDungeonController) -> void:
	_scene_path = scene_path
	_player = player

## Switches an entry off for this menu alone, leaving the authored PauseMenuItem untouched.
## Callable right after add_child(), which is when _ready() has already built the labels.
func set_action_disabled(action: StringName, value: bool) -> void:
	_runtime_disabled[action] = value
	if is_node_ready():
		_refresh_ui()

func _ready() -> void:
	visible = false
	_build_ui()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("btn_start"):
			_open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("btn_a"):
		var item := menu_items[_item_selected]
		if item and not _is_item_disabled(item):
			AudioManager.play_sfx(AudioManager.ui_select_sound, -8.0)
			if has_method(item.action):
				call(item.action)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("btn_b"):
		_close()
		get_viewport().set_input_as_handled()
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

func _build_ui() -> void:
	for menu_item in menu_items:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_override("font", GameState.get_text_font())
		label.add_theme_font_size_override("font_size", 16)
		var color := Palette.SRC_DARK if _is_item_disabled(menu_item) else Palette.SRC_LIGHTEST
		label.add_theme_color_override("font_color", color)
		label.text = menu_item.text
		_menu_list.add_child(label)

func _refresh_ui() -> void:
	for index in _menu_list.get_child_count():
		var label := _menu_list.get_child(index) as Label
		var item := menu_items[index]
		if item == null or label == null:
			continue
		var color := Palette.SRC_LIGHTEST
		if _is_item_disabled(item):
			color = Palette.SRC_DARK
		elif index == _item_selected:
			color = Palette.SRC_LIGHT
		label.add_theme_color_override("font_color", color)

func _is_item_disabled(item: PauseMenuItem) -> bool:
	return item.disabled or _runtime_disabled.get(item.action, false)

func _move_list_selection(dy: int) -> void:
	var count := _menu_list.get_child_count()
	if count == 0:
		return
	var index := clampi(_item_selected + dy, 0, count - 1)
	if index == _item_selected:
		return
	var item := menu_items[index]
	if _is_item_disabled(item):
		_move_list_selection(dy + sign(dy))
		return
	_item_selected = index
	_refresh_ui()
	AudioManager.play_sfx(AudioManager.ui_move_sound, -10.0)

func _open() -> void:
	GameState.set_paused(true)
	_item_selected = 0
	_refresh_ui()
	visible = true

func _close() -> void:
	GameState.set_paused(false)
	visible = false

func _resume_game() -> void:
	_close()

func _open_inventory() -> void:
	# Only a scene that called setup() has somewhere to go back to, see DungeonManager._init_hud()
	if _player == null or _scene_path.is_empty():
		push_warning("Inventory asked for from a scene that never called setup()")
		return
	var payload := {
		"scene_path": _scene_path,
		"player_position": _player.global_position
	}
	SceneManager.go_to(INVENTORY_SCENE_PATH, payload)

func _open_settings() -> void:
	# Only a scene that called setup() has somewhere to go back to, see DungeonManager._init_hud()
	if _player == null or _scene_path.is_empty():
		push_warning("Settings asked for from a scene that never called setup()")
		return
	var payload := {
		"scene_path": _scene_path,
		"player_position": _player.global_position
	}
	SceneManager.go_to(SETTINGS_SCENE_PATH, payload)

func _exit_game() -> void:
	AudioManager.stop_music()
	SceneManager.go_to(LEVEL_SEL_SCENE_PATH)
