extends Node2D

const TITLE_SCREEN_SCENE_PATH: String = "res://scenes/game/title_screen.tscn"
const HOW_TO_PLAY_SCENE_PATH: String = "res://scenes/game/how_to_play.tscn"
const LEVEL_ICON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/level_selection_level_item.png")
const LEVEL_ICON_TEXTURE_REGION: Rect2 = Rect2(0.0, 0.0, 24.0, 24.0)
const LEVEL_SELECTED_ICON_TEXTURE_REGION: Rect2 = Rect2(24.0, 0.0, 24.0, 24.0)

@onready var _levels_container: Control = $Container/Levels
@onready var _selection_icon: AnimatedSprite2D = $SelectionIcon
@onready var _level_title_label: Label = $Container/LevelInfo/Control/LevelTitle
@onready var _level_text_label: Label = $Container/LevelInfo/Control/LevelText
@onready var _level_shovel_label: Label = $Container/LevelInfo/Control/LevelStats/Shovel/Label
@onready var _level_key_label: Label = $Container/LevelInfo/Control/LevelStats/Key/Label
@onready var _level_torch_label: Label = $Container/LevelInfo/Control/LevelStats/Torch/Label

var _item_selected: int = 0

func _ready() -> void:
	# Reaching this screen ends a run, whether the player finished the level, quit it or died, so
	# this is the single place the world state has to be wiped. Harmless on boot: this scene is
	# main.tscn's initial_scene.
	GameState.reset_run()
	GameState.set_paused(false)
	SignalBus.visibility_shader_toggled.emit(false)
	SceneManager.get_main_scene().toggle_bottom_bar(false)

	AudioManager.stop_music()
	AudioManager.play_music(AudioManager.level_selection_theme, 0.0)

	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_a"):
		_confirm_level()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("btn_b"):
		SceneManager.go_to(TITLE_SCREEN_SCENE_PATH)
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

func _refresh_ui() -> void:
	var levels_count := _levels_container.get_child_count()
	for index in levels_count:
		var node := _levels_container.get_child(index)
		if node == null or node is not LevelSelectionItem:
			return
		var tex_rect := node as TextureRect
		var atlas := AtlasTexture.new()
		atlas.atlas = LEVEL_ICON_TEXTURE
		atlas.region = LEVEL_SELECTED_ICON_TEXTURE_REGION if index == _item_selected else LEVEL_ICON_TEXTURE_REGION
		tex_rect.texture = atlas
		if _item_selected == index:
			if _selection_icon:
				_selection_icon.position = tex_rect.global_position
				_selection_icon.position.x += tex_rect.size.x / 2
				_selection_icon.position.y += 2
			var level := (node as LevelSelectionItem).level_info
			if level:
				_level_title_label.text = level.title
				_level_text_label.text = level.short_text
				_level_shovel_label.text = "%02d" % level.digging_spots
				_level_key_label.text = "%02d" % level.keys
				_level_torch_label.text = "%02d" % level.torches

func _move_list_selection(dy: int) -> void:
	var count := _levels_container.get_child_count()
	if count == 0:
		return
	var index := clampi(_item_selected + dy, 0, count - 1)
	if index == _item_selected:
		return
	_item_selected = index
	_refresh_ui()
	AudioManager.play_sfx(AudioManager.ui_move_sound, -10.0)

func _confirm_level() -> void:
	var levels_count := _levels_container.get_child_count()
	if _item_selected >= 0 and _item_selected < levels_count:
		var node := _levels_container.get_child(_item_selected)
		if node == null or node is not LevelSelectionItem:
			return
		var level := (node as LevelSelectionItem).level_info
		if level and level.level_scene != null:
			if GameState.is_first_play():
				GameState.set_first_play(false)
				SceneManager.go_to(HOW_TO_PLAY_SCENE_PATH, {
					"next_scene_path": level.level_scene.resource_path,
					"hard_reset": true
				})
			else:
				SceneManager.go_to(level.level_scene.resource_path, { "hard_reset": true })
