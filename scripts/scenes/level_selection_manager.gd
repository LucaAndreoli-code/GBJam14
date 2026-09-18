extends Node2D

const ICONS_TEXTURE_PATH: Texture2D = preload("res://assets/sprites/ui/ui_mini_icons.png")
const SHOVEL_ICON_TEXTURE_REGION: Rect2 = Rect2(0.0, 0.0, 8.0, 8.0)
const KEY_ICON_TEXTURE_REGION: Rect2 = Rect2(8.0, 0.0, 8.0, 8.0)
const TORCH_ICON_TEXTURE_REGION: Rect2 = Rect2(16.0, 0.0, 8.0, 8.0)

@onready var _list: VBoxContainer = $Container/ListContainer/List

@export var levels: Array[LevelSelectionItem] = []

var _item_selected: int = 0

func _ready() -> void:
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	_build_ui()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_a"):
		_confirm_level()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("btn_b"):
		#_close()
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
	for i in range(levels.size()):
		var level := levels[i]
		var container := HBoxContainer.new()
		container.add_theme_constant_override("separation", 9)
		var style := StyleBoxFlat.new()
		style.border_width_bottom = 1
		style.border_color = Palette.SRC_LIGHT
		container.add_theme_stylebox_override("normal", style)
		var label := Label.new()
		label.add_theme_font_override("font", GameState.get_text_font())
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Palette.SRC_LIGHTEST)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = level.text
		container.add_child(label)
		container.add_child(_make_icon(ICONS_TEXTURE_PATH, SHOVEL_ICON_TEXTURE_REGION, level.digging_spots))
		container.add_child(_make_icon(ICONS_TEXTURE_PATH, KEY_ICON_TEXTURE_REGION, level.keys))
		container.add_child(_make_icon(ICONS_TEXTURE_PATH, TORCH_ICON_TEXTURE_REGION, level.torches))
		_list.add_child(container)

func _make_icon(texture: Texture2D, rect: Rect2, amount: int) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rect
	var texture_rect := TextureRect.new()
	texture_rect.texture = atlas
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var label := Label.new()
	label.add_theme_font_override("font", GameState.get_text_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Palette.SRC_LIGHTEST)
	label.text = "%02d" % amount
	container.add_child(texture_rect)
	container.add_child(label)
	return container

func _refresh_ui() -> void:
	for index in _list.get_child_count():
		var container := _list.get_child(index) as HBoxContainer
		var level := levels[index]
		if level == null or container == null:
			continue
		var color := Palette.SRC_LIGHTEST
		if level.disabled:
			color = Palette.SRC_DARK
		elif index == _item_selected:
			color = Palette.SRC_LIGHT
		container.get_child(0).add_theme_color_override("font_color", color)

func _move_list_selection(dy: int) -> void:
	var count := _list.get_child_count()
	if count == 0:
		return
	var index := clampi(_item_selected + dy, 0, count - 1)
	if index == _item_selected:
		return
	_item_selected = index
	_refresh_ui()

func _confirm_level() -> void:
	if _item_selected >= 0 and _item_selected < levels.size():
		var level := levels[_item_selected]
		if level and level.level_scene != null:
			SceneManager.go_to(level.level_scene.resource_path)
