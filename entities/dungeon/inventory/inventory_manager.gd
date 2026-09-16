extends Node2D

const FRAME_NOT_SELECTED: Rect2i = Rect2i(0, 0, 24, 24)
const FRAME_SELECTED: Rect2i = Rect2i(24, 0, 24, 24)
const QUESTION_MARK: Rect2i = Rect2i(52, 4, 16, 16)

@onready var _grid: GridContainer = $Container/CenterGrid/Grid
@onready var _info_control: Control = $Container/Info

@export var grid_size: Vector2i = Vector2i(4, 3)
@export var cell_textures: Texture2D

var _cell_selected: int = 0

func _ready() -> void:
	if _grid:
		_init_grid()
		_refresh_grid()

func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().visible:
		return
	var dx := 0
	var dy := 0
	if event.is_action_pressed("dpad_right"):
		dx = 1
	elif event.is_action_pressed("dpad_left"):
		dx = -1
	elif event.is_action_pressed("dpad_down"):
		dy = 1
	elif event.is_action_pressed("dpad_up"):
		dy = -1
	if dx == 0 and dy == 0:
		return
	get_viewport().set_input_as_handled()
	_move_grid_selection(dx, dy)

func _init_grid() -> void:
	_grid.columns = grid_size.x
	for child in _grid.get_children():
		child.queue_free()
	for i in grid_size.x * grid_size.y:
		_grid.add_child(_make_grid_cell())

func _make_grid_cell() -> Control:
	var cell := TextureRect.new()
	var cell_atlas := AtlasTexture.new()
	cell_atlas.atlas = cell_textures
	cell_atlas.region = FRAME_NOT_SELECTED
	cell.texture = cell_atlas
	cell.stretch_mode = TextureRect.STRETCH_KEEP
	cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sub_cell := TextureRect.new()
	var sub_cell_atlas := AtlasTexture.new()
	sub_cell_atlas.atlas = cell_textures
	sub_cell_atlas.region = QUESTION_MARK
	sub_cell.position = Vector2(4.0, 4.0)
	sub_cell.texture = sub_cell_atlas
	sub_cell.stretch_mode = TextureRect.STRETCH_KEEP
	sub_cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cell.add_child(sub_cell)
	return cell

func _move_grid_selection(dx: int, dy: int) -> void:
	var count := _grid.get_child_count()
	if count == 0:
		return
	var x := _cell_selected % grid_size.x
	var y := _cell_selected / grid_size.x
	x = clampi(x + dx, 0, grid_size.x - 1)
	y = clampi(y + dy, 0, grid_size.y - 1)
	var index := y * grid_size.x + x
	if index >= count or index == _cell_selected:
		return
	_cell_selected = index
	_refresh_grid()

func _refresh_grid() -> void:
	for i in _grid.get_child_count():
		var cell := _grid.get_child(i) as TextureRect
		(cell.texture as AtlasTexture).region = FRAME_SELECTED if _cell_selected == i else FRAME_NOT_SELECTED
