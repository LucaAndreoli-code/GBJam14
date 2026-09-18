extends Node2D

#@onready var _list_container: ScrollContainer = $Container/ListContainer
@onready var _list: VBoxContainer = $Container/ListContainer/List

@export var levels: Array[LevelSelectionItem] = []

var _item_selected: int = 0

func _ready() -> void:
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	_build_ui()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_a"):
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
		var label := Label.new()
		label.add_theme_font_override("font", GameState.get_text_font())
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Palette.SRC_LIGHTEST)
		label.text = level.text
		_list.add_child(label)

func _refresh_ui() -> void:
	for index in _list.get_child_count():
		var label := _list.get_child(index) as Label
		var level := levels[index]
		if level == null or label == null:
			continue
		var color := Palette.SRC_LIGHTEST
		if level.disabled:
			color = Palette.SRC_DARK
		elif index == _item_selected:
			color = Palette.SRC_LIGHT
		label.add_theme_color_override("font_color", color)

func _move_list_selection(dy: int) -> void:
	var count := _list.get_child_count()
	if count == 0:
		return
	var index := clampi(_item_selected + dy, 0, count - 1)
	if index == _item_selected:
		return
	_item_selected = index
	_refresh_ui()
